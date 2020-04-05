//
//  Parsing.swift
//  PitchShifter
//
//  Created by David Solis on 4/4/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import AVFoundation

/// The `Parsing` protocol represents a generic parser that can be used for converting binary data into audio packets.
protocol Parsing: class {
    
    // MARK: - Properties
        
    /// The data format of the audio. This describes the sample rate, frames per packet, bytes per packet, etc.
    var dataFormat: AVAudioFormat? { get }
    
    /// The total duration of the audio. For certain formats such as AAC or live streams this may be a guess or only equal to as many packets
    /// as have been processed.
    var duration: TimeInterval? { get }
    
    /// A `Bool` indicating whether all the audio packets have been parsed relative to the total packet count. This is optional where the default implementation
    /// will check if the total packets parsed (i.e. the count of `packets` property) is equal to the `totalPacketCount` property
    var isParsingComplete: Bool { get }
    
    /// An array of duples, each index presenting a parsed audio packet. For compressed formats each packet of data should contain a
    /// `AudioStreamPacketDescription`, which describes the start offset and length of the audio data)
    var packets: [(Data, AudioStreamPacketDescription?)] { get }
    
    /// The total number of frames (expressed in the data format)
    var totalFrameCount: AVAudioFrameCount? { get }
    
    /// The total packet count (expressed in the data format)
    var totalPacketCount: AVAudioPacketCount? { get }
    
    // MARK: - Methods
    
    /// Given some data the parser should attempt to convert it into to audio packets.
    ///
    /// - Parameter data: A `Data` instance representing some binary data corresponding to an audio stream.
    func parse(data: Data) throws
    
    /// Given a time this method will attempt to provide the corresponding audio frame representing that position.
    ///
    /// - Parameter time: A `TimeInterval` representing the time
    /// - Returns: An optional `AVAudioFramePosition` representing the frame's position relative to the time provided. If the `dataFormat`, total
    ///  frame count, or duration is unknown then this will return nil.
    func frameOffset(forTime time: TimeInterval) -> AVAudioFramePosition?
    
    /// Given a frame this method will attempt to provide the corresponding audio packet representing that position.
    ///
    /// - Parameter frame: An `AVAudioFrameCount` representing the desired frame
    /// - Returns: An optional `AVAudioPacketCount` representing the packet the frame belongs to. If the `dataFormat` is unknown (not enough
    ///  data has been provided) then this will return nil.
    func packetOffset(forFrame frame: AVAudioFramePosition) -> AVAudioPacketCount?
    
    /// Given a frame this method will attempt to provide the corresponding time relative to the duration representing that position.
    ///
    /// - Parameter frame: An `AVAudioFrameCount` representing the desired frame
    /// - Returns: An optional `TimeInterval` representing the time relative to the frame. If the `dataFormat`, total frame count, or duration is
    /// unknown then this will return nil.
    func timeOffset(forFrame frame: AVAudioFrameCount) -> TimeInterval?
    
}

// Usually these methods are gonna be calculated using the same way everytime so here are the default implementations
// that should work 99% of the time relative to the properties defined.
extension Parsing {
    
    var duration: TimeInterval? {
        guard let sampleRate = dataFormat?.sampleRate else {
            return nil
        }
        
        guard let totalFrameCount = totalFrameCount else {
            return nil
        }
        
        return TimeInterval(totalFrameCount) / TimeInterval(sampleRate)
    }
    
    var totalFrameCount: AVAudioFrameCount? {
        guard let framesPerPacket = dataFormat?.streamDescription.pointee.mFramesPerPacket else {
            return nil
        }
        
        guard let totalPacketCount = totalPacketCount else {
            return nil
        }
        
        return AVAudioFrameCount(totalPacketCount) * AVAudioFrameCount(framesPerPacket)
    }
    
    var isParsingComplete: Bool {
        guard let totalPacketCount = totalPacketCount else {
            return false
        }
        
        return packets.count == totalPacketCount
    }
    
    func frameOffset(forTime time: TimeInterval) -> AVAudioFramePosition? {
        guard let _ = dataFormat?.streamDescription.pointee,
            let frameCount = totalFrameCount,
            let duration = duration else {
                return nil
        }
        
        let ratio = time / duration
        return AVAudioFramePosition(Double(frameCount) * ratio)
    }
    
    func packetOffset(forFrame frame: AVAudioFramePosition) -> AVAudioPacketCount? {
        guard let framesPerPacket = dataFormat?.streamDescription.pointee.mFramesPerPacket else {
            return nil
        }
        
        return AVAudioPacketCount(frame) / AVAudioPacketCount(framesPerPacket)
    }
    
    func timeOffset(forFrame frame: AVAudioFrameCount) -> TimeInterval? {
        guard let _ = dataFormat?.streamDescription.pointee,
            let frameCount = totalFrameCount,
            let duration = duration else {
                return nil
        }
        
        return TimeInterval(frame) / TimeInterval(frameCount) * duration
    }
}
