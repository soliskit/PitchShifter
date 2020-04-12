//
//  Streamer.swift
//  PitchShifter
//
//  Created by David Solis on 4/5/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import os.log
import AVFoundation

/// The `Streamer` is a concrete implementation of the `Streaming` protocol and is intended to provide a high-level, extendable class for streaming an audio file living at a URL on the internet. Subclasses can override the `attachNodes` and `connectNodes` methods to insert custom effects.
class Streamer: Streaming {
    
    static let logger = OSLog(subsystem: "co.peaking.pitchShifter", category: "Streamer")
    
    // MARK: - Properties
    
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    /// An `AVAudioUnitTimePitch` used to perform the time/pitch shift effect
    let timePitchNode = AVAudioUnitTimePitch()
    lazy var downloader: Downloading = {
        let downloader = Downloader()
        downloader.delegate = self
        
        return downloader
    }()
    var delegate: StreamingDelegate?
    var parser: Parsing?
    var reader: Reading?
    /// A `Bool` indicating whether the file has been completely scheduled into the player node.
    var isFileSchedulingComplete = false
    var url: URL? {
        didSet {
            reset()
            if let url = url {
                downloader.url = url
                downloader.start()
            }
        }
    }
    var state: StreamingState = .stopped {
        didSet {
            delegate?.streamer(self, changedState: state)
        }
    }
    var duration: TimeInterval?
    /// A `TimeInterval` used to calculate the current play time relative to a seek operation.
    var currentTime: TimeInterval? {
        guard let nodeTime = playerNode.lastRenderTime,
            let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else {
            return currentTimeOffset
        }
        let currentTime = TimeInterval(playerTime.sampleTime) / playerTime.sampleRate
        
        return currentTime + currentTimeOffset
    }
    var currentTimeOffset: TimeInterval = 0
    var volume: Float {
        get {
            return engine.mainMixerNode.outputVolume
        }
        set {
            engine.mainMixerNode.outputVolume = newValue
        }
    }
    var volumeRampTimer: Timer?
    var volumeRampTargetValue: Float?
    /// A `Float` representing the pitch of the audio
    var pitch: Float {
        get {
            return timePitchNode.pitch
        }
        set {
            timePitchNode.pitch = newValue
        }
    }
    /// A `Float` representing the playback rate of the audio
    var rate: Float {
        get {
            return timePitchNode.rate
        }
        set {
            timePitchNode.rate = newValue
        }
    }

    // MARK: - Lifecycle
    
    init() {
        // Setup the audio engine (attach nodes, connect stuff, etc). No playback yet.
        setupAudioEngine()
    }

    // MARK: - Setup

    func setupAudioEngine() {
        os_log("%@ - line %d", log: Streamer.logger, type: .debug, #function, #line)
        
        // Attach nodes
        attachNodes()

        // Node nodes
        connectNodes()

        // Prepare the engine
        engine.prepare()
        
        /// Use timer to schedule the buffers (this is not ideal, wish AVAudioEngine provided a pull-model for scheduling buffers)
        let interval = 1 / (readFormat.sampleRate / Double(readBufferSize))
        let timer = Timer(timeInterval: interval / 2, repeats: true) { [weak self] _ in
            guard self?.state != .stopped else {
                return
            }
            
            self?.scheduleNextBuffer()
            self?.handleTimeUpdate()
            self?.notifyTimeUpdated()
        }
        RunLoop.current.add(timer, forMode: .common)
    }

    /// Subclass can override this to attach additional nodes to the engine before it is prepared. Default implementation attaches the `playerNode`. Subclass should call super or be sure to attach the playerNode.
    func attachNodes() {
        engine.attach(playerNode)
        engine.attach(timePitchNode)
    }

    /// Subclass can override this to make custom node connections in the engine before it is prepared. Default implementation connects the playerNode to the mainMixerNode on the `AVAudioEngine` using the default `readFormat`. Subclass should use the `readFormat` property when connecting nodes.
    func connectNodes() {
        engine.connect(playerNode, to: timePitchNode, format: readFormat)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: readFormat)
    }
    
    // MARK: - Reset
    
    func reset() {
        os_log("%@ - line %d", log: Streamer.logger, type: .debug, #function, #line)
        
        // Reset the playback state
        stop()
        duration = nil
        reader = nil
        isFileSchedulingComplete = false
        
        // Create a new parser
        do {
            parser = try Parser()
        } catch {
            os_log("[error: Failed to create parser] - line %d", log: Streamer.logger, type: .error, #line)
            print(error.localizedDescription)
            return
        }
    }
    
    // MARK: - Methods
    
    func play() {
        os_log("%@ - line %d", log: Streamer.logger, type: .debug, #function, #line)
        
        // Check we're not already playing
        guard !playerNode.isPlaying else {
            return
        }
        
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                os_log("[error: Failed to start engine] - line %d", log: Streamer.logger, type: .error, #line)
                print(error.localizedDescription)
                return
            }
        }
        
        // To make the volume change less harsh we mute the output volume
        let lastVolume = volumeRampTargetValue ?? volume
        volume = 0
        
        // Start playback on the player node
        playerNode.play()
        
        // After 250ms we restore the volume to where it was
        swellVolume(to: lastVolume)
        
        // Update the state
        state = .playing
    }
    
    func pause() {
        os_log("%@ - line %d", log: Streamer.logger, type: .debug, #function, #line)
        
        // Check if the player node is playing
        guard playerNode.isPlaying else {
            return
        }
        
        // Pause the player node and the engine
        playerNode.pause()
        
        // Update the state
        state = .paused
    }
    
    func stop() {
        os_log("%@ - line %d", log: Streamer.logger, type: .debug, #function, #line)
        
        // Stop the downloader, the player node, and the engine
        downloader.stop()
        playerNode.stop()
        engine.stop()
        
        // Update the state
        state = .stopped
    }
    
    func seek(to time: TimeInterval) throws {
        os_log("%@ [%.1f] - line %d", log: Streamer.logger, type: .debug, #function, time, #line)
        
        // Make sure we have a valid parser and reader
        guard let parser = parser, let reader = reader else {
            os_log("[debug: No reader or parser yet] - line %d", log: Streamer.logger, type: .debug, #line)
            return
        }
        
        // Get the proper time and packet offset for the seek operation
        guard let frameOffset = parser.frameOffset(forTime: time),
            let packetOffset = parser.packetOffset(forFrame: frameOffset) else {
                return
        }
        currentTimeOffset = time
        isFileSchedulingComplete = false
        
        // We need to store whether or not the player node is currently playing to properly resume playback after
        let isPlaying = playerNode.isPlaying
        let lastVolume = volumeRampTargetValue ?? volume
        
        // Stop the player node to reset the time offset to 0
        playerNode.stop()
        volume = 0
        
        // Perform the seek to the proper packet offset
        do {
            try reader.seek(packetOffset)
        } catch {
            os_log("[error: Failed to seek] - line %d", log: Streamer.logger, type: .error, #line)
            print(error.localizedDescription)
            return
        }
        
        // If the player node was previous playing then resume playback
        if isPlaying {
            playerNode.play()
        }
        
        // Update the current time
        delegate?.streamer(self, updatedCurrentTime: time)
        
        // After 250ms we restore the volume back to where it was
        swellVolume(to: lastVolume)
    }
    
    func swellVolume(to newVolume: Float, duration: TimeInterval = 0.5) {
        volumeRampTargetValue = newVolume
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(duration*1000/2))) { [unowned self] in
            self.volumeRampTimer?.invalidate()
            let timer = Timer(timeInterval: Double(Float((duration/2.0))/(newVolume * 10)), repeats: true) { timer in
                if self.volume != newVolume {
                    self.volume = min(newVolume, self.volume + 0.1)
                } else {
                    self.volumeRampTimer = nil
                    self.volumeRampTargetValue = nil
                    timer.invalidate()
                }
            }
            RunLoop.current.add(timer, forMode: .common)
            self.volumeRampTimer = timer
        }
    }

    // MARK: - Scheduling Buffers

    func scheduleNextBuffer() {
        guard let reader = reader else {
            os_log("No reader yet - line %d", log: Streamer.logger, type: .debug, #line)
            return
        }

        guard !isFileSchedulingComplete else {
            return
        }

        do {
            let nextScheduledBuffer = try reader.read(readBufferSize)
            playerNode.scheduleBuffer(nextScheduledBuffer)
        } catch ReaderError.reachedEndOfFile {
            os_log("Scheduler reached end of file - line %d", log: Streamer.logger, type: .debug, #line)
            isFileSchedulingComplete = true
        } catch {
            os_log("Cannot schedule buffer [error: %@] - line %d", log: Streamer.logger, type: .debug, error.localizedDescription, #line)
            return
        }
    }

    // MARK: - Handling Time Updates
    
    /// Handles the duration value, explicitly checking if the duration is greater than the current value. For indeterminate streams we can accurately estimate the duration using the number of packets parsed and multiplying that by the number of frames per packet.
    func handleDurationUpdate() {
        if let newDuration = parser?.duration {
            // Check if the duration is either nil or if it is greater than the previous duration
            var shouldUpdate = false
            if duration == nil {
                shouldUpdate = true
            } else if let oldDuration = duration, oldDuration < newDuration {
                shouldUpdate = true
            }
            
            // Update the duration value
            if shouldUpdate {
                self.duration = newDuration
                notifyDurationUpdate(newDuration)
            }
        }
    }
    
    /// Handles the current time relative to the duration to make sure current time does not exceed the duration
    func handleTimeUpdate() {
        guard let currentTime = currentTime, let duration = duration else {
            return
        }

        if currentTime >= duration {
            try? seek(to: 0)
            pause()
        }
    }

    // MARK: - Notifying The Delegate

    func notifyDownloadProgress(_ progress: Float) {
        guard let url = url else {
            fatalError("Invalid URL")
        }

        delegate?.streamer(self, updatedDownloadProgress: progress, forURL: url)
    }

    func notifyDurationUpdate(_ duration: TimeInterval) {
        guard let _ = url else {
            fatalError("Invalid URL")
        }

        delegate?.streamer(self, updatedDuration: duration)
    }

    func notifyTimeUpdated() {
        guard engine.isRunning, playerNode.isPlaying else {
            return
        }

        guard let currentTime = currentTime else {
            return
        }

        delegate?.streamer(self, updatedCurrentTime: currentTime)
    }
}
