//
//  Parser.swift
//  PitchShifter
//
//  Created by David Solis on 4/4/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import AVFoundation

class Parser: Parsing {
    
    var dataFormat: AVAudioFormat?
    
    var packets = [(Data, AudioStreamPacketDescription?)]()
    
    var totalPacketCount: AVAudioPacketCount? {
        guard let _ = dataFormat else {
            return nil
        }
        return max(AVAudioPacketCount(packetCount), AVAudioPacketCount(packets.count))
    }
    
     /// A `UInt64` corresponding to the total frame count parsed by the Audio File Stream Services
    var frameCount: UInt64 = 0
       
    /// A `UInt64` corresponding to the total packet count parsed by the Audio File Stream Services
    var packetCount: UInt64 = 0
       
    /// The `AudioFileStreamID` used by the Audio File Stream Services for converting the binary data into audio packets
    var streamID: AudioFileStreamID?
    
    init() throws {
        let context = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        guard AudioFileStreamOpen(context, ParserPropertyChangeCallback, ParserPacketCallback, kAudioFileMP3Type, &streamID) == noErr else {
            throw ParserError.streamCouldNotOpen
          }
    }
    
    func parse(data: Data) throws {
        guard let streamID = self.streamID else {
            fatalError("Missing streamID")
        }
        let count = data.count
        _ = try data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) in
              let result = AudioFileStreamParseBytes(streamID, UInt32(count), bytes, [])
              guard result == noErr else {
                throw ParserError.failedToParseBytes(result)
              }
          }
    }
}
