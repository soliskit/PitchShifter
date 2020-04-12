//
//  ViewController.swift
//  PitchShifter
//
//  Created by David Solis on 3/19/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import os.log
import UIKit
import AVFoundation
import SwiftAudioPlayer

class ViewController: UIViewController {
    
    static let logger = OSLog(subsystem: "co.peaking.pitchShifter", category: "ViewController")
    
    // MARK: - Outlets
    @IBOutlet weak var pitchLabel: UILabel!
    @IBOutlet weak var pitchSlider: UISlider!
    @IBOutlet weak var rateLabel: UILabel!
    @IBOutlet weak var rateSlider: UISlider!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationTimeLabel: UILabel!
    @IBOutlet weak var progressSlider: ProgressSlider!
    @IBOutlet weak var playButton: UIButton!
    
    // MARK: - Properties
    lazy var streamer: Streamer = {
        let streamer = Streamer()
        streamer.delegate = self
        return streamer
    }()
    
    // Used so we can use the current time slider continuously, but only seek when the user touches up
    var isSeeking = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the AVAudioSession and AVAudioEngine
        setupAudioSession()
        
        // Reset the pitch and rate
        resetPitch(self)
        resetRate(self)
        
        /// Download
        let url = URL(string: "https://cdn.fastlearner.media/bensound-rumble.mp3")!
        streamer.url = url
    }
    
    // MARK: - Setting Up The Engine
    
    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, policy: .default, options: [.allowBluetoothA2DP,.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            os_log("%@ [error: Failed to activate audio session] - line %d", log: ViewController.logger, type: .error, #function, #line)
            print(error.localizedDescription)
        }
    }

    // MARK: - Playback
    
    @IBAction func togglePlayback(_ sender: UIButton) {
        if streamer.state == .playing {
            streamer.pause()
            
        } else {
            streamer.play()
        }
    }
    
    // MARK: - Handle Seeking
    
    @IBAction func seek(_ sender: UISlider) {
        os_log("%@ [%.1f] - line %d", log: ViewController.logger, type: .debug, #function, progressSlider.value, #line)
        
        do {
            let time = TimeInterval(progressSlider.value)
            try streamer.seek(to: time)
        } catch {
            os_log("[error: Failed to seek] - line %d", log: ViewController.logger, type: .error, #line)
            print("\(error.localizedDescription)")
            return
        }
    }
    
    @IBAction func progressSliderTouchedDown(_ sender: UISlider) {
        os_log("%@ - line %d", log: ViewController.logger, type: .debug, #function, #line)
        
        isSeeking = true
    }
    
    @IBAction func progressSliderValueChanged(_ sender: UISlider) {
        os_log("%@ - line %d", log: ViewController.logger, type: .debug, #function, #line)
        
        let currentTime = TimeInterval(progressSlider.value)
        currentTimeLabel.text = currentTime.toMMSS()
    }
    
    @IBAction func progressSliderTouchedUp(_ sender: UISlider) {
        os_log("%@ - line %d", log: ViewController.logger, type: .debug, #function, #line)
        
        seek(sender)
        isSeeking = false
    }
    
    // MARK: - Change Pitch
    
    @IBAction func changePitch(_ sender: UISlider) {
        os_log("%@ [%.1f] - line %d", log: ViewController.logger, type: .debug, #function, sender.value, #line)
        
        let step: Float = 100
        var pitch = roundf(pitchSlider.value)
        let newStep = roundf(pitch / step)
        pitch = newStep * step
        streamer.pitch = pitch
        pitchSlider.value = pitch
        pitchLabel.text = String(format: "%i cents", Int(pitch))
    }
    
    @IBAction func resetPitch(_ sender: Any) {
        let pitch: Float = 0
        streamer.pitch = pitch
        pitchLabel.text = String(format: "%i cents", Int(pitch))
        pitchSlider.value = pitch
        
        os_log("%@ [%.1f] - line %d", log: ViewController.logger, type: .debug, #function, pitch, #line)
    }
    
    // MARK: - Change Rate
    
    @IBAction func changeRate(_ sender: UISlider) {
        os_log("%@ [%.1f] - line %d", log: ViewController.logger, type: .debug, #function, sender.value, #line)
        
        let step: Float = 0.25
        var rate = rateSlider.value
        let newStep = roundf(rate / step)
        rate = newStep * step
        streamer.rate = rate
        rateSlider.value = rate
        rateLabel.text = String(format: "%.2fx", rate)
    }
    
    @IBAction func resetRate(_ sender: Any) {
        let rate: Float = 1
        streamer.rate = rate
        rateLabel.text = String(format: "%.2fx", rate)
        rateSlider.value = rate
        
        os_log("%@ [%.1f] - line %d", log: ViewController.logger, type: .debug, #function, rate, #line)
    }
}

extension ViewController: StreamingDelegate {
    
    func streamer(_ streamer: Streaming, failedDownloadWithError error: Error, forURL url: URL) {
        os_log("%@ [%@] - line %d", log: ViewController.logger, type: .debug, #function, error.localizedDescription, #line)
        
        let alert = UIAlertController(title: "Download Failed",
                                      message: error.localizedDescription,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            alert.dismiss(animated: true, completion: nil)
        }))
        show(alert, sender: self)
    }
    
    func streamer(_ streamer: Streaming, updatedDownloadProgress progress: Float, forURL url: URL) {
        os_log("%@ [progress: %.2f] - line %d", log: ViewController.logger, type: .debug, #function, progress, #line)
        
        progressSlider.progress = progress
    }
    
    func streamer(_ streamer: Streaming, changedState state: StreamingState) {
        os_log("%@ [state: %@] - line %d", log: ViewController.logger, type: .debug, #function, state.rawValue, #line)
        
        switch state {
        case .playing:
            playButton.setImage(#imageLiteral(resourceName: "pause"), for: .normal)
        case .paused, .stopped:
            playButton.setImage(#imageLiteral(resourceName: "play"), for: .normal)
        }
    }
    
    func streamer(_ streamer: Streaming, updatedCurrentTime currentTime: TimeInterval) {
        os_log("%@ [currentTime: %@] - line %d", log: ViewController.logger, type: .debug, #function, currentTime.toMMSS(), #line)
        
        if !isSeeking {
            progressSlider.value = Float(currentTime)
            currentTimeLabel.text = currentTime.toMMSS()
        }
    }
    
    func streamer(_ streamer: Streaming, updatedDuration duration: TimeInterval) {
        let formattedDuration = duration.toMMSS()
        os_log("%@ [duration: %@] - line %d", log: ViewController.logger, type: .debug, #function, formattedDuration, #line)
        
        durationTimeLabel.text = formattedDuration
        durationTimeLabel.isEnabled = true
        playButton.isEnabled = true
        progressSlider.isEnabled = true
        progressSlider.minimumValue = 0.0
        progressSlider.maximumValue = Float(duration)
    }
}
