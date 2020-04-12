//
//  ParserPropertyListener.swift
//  PitchShifter
//
//  Created by David Solis on 4/5/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import os.log
import AVFoundation
       
func ParserPropertyChangeCallback(_ context: UnsafeMutableRawPointer,
                                  _ streamID: AudioFileStreamID,
                                  _ propertyID: AudioFileStreamPropertyID,
                                  _ flags: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) {
    let parser = Unmanaged<Parser>.fromOpaque(context).takeUnretainedValue()
    
    /// Parse the various properties
    switch propertyID {
    case kAudioFileStreamProperty_DataFormat:
        var format = AudioStreamBasicDescription()
        GetPropertyValue(&format, streamID, propertyID)
        parser.dataFormat = AVAudioFormat(streamDescription: &format)
        os_log("Data format: %@ - line %d", log: Parser.loggerPropertyListenerCallback, type: .debug, String(describing: parser.dataFormat), #line)
        
    case kAudioFileStreamProperty_AudioDataPacketCount:
        GetPropertyValue(&parser.packetCount, streamID, propertyID)
        os_log("Packet count: [%i] - line %d", log: Parser.loggerPropertyListenerCallback, type: .debug, parser.packetCount, #line)

    default:
        os_log("%@ - line %d", log: Parser.loggerPropertyListenerCallback, type: .debug, propertyID.description, #line)
    }
}

// MARK: - Utilities

/// Generic method for getting an AudioFileStream property. This method takes care of getting the size of the property and takes in the expected
///  value type and reads it into the value provided. Note it is an inout method so the value passed in will be mutated. This is not as
///  functional as we'd like, but allows us to make this method generic.
///
/// - Parameters:
///   - value: A value of the expected type of the underlying property
///   - streamID: An `AudioFileStreamID` representing the current audio file stream parser.
///   - propertyID: An `AudioFileStreamPropertyID` representing the particular property to get.
func GetPropertyValue<T>(_ value: inout T, _ streamID: AudioFileStreamID, _ propertyID: AudioFileStreamPropertyID) {
    var propSize: UInt32 = 0
    guard AudioFileStreamGetPropertyInfo(streamID, propertyID, &propSize, nil) == noErr else {
        os_log("Failed to get info for property: %@ - line %d", log: Parser.loggerPropertyListenerCallback, type: .error, "\(propertyID)", #line)
        return
    }
    guard AudioFileStreamGetProperty(streamID, propertyID, &propSize, &value) == noErr else {
        os_log("Failed to get value [%@] - line %d", log: Parser.loggerPropertyListenerCallback, type: .error, "\(propertyID)", #line)
        return
    }
}

func ParserPacketCallback(_ context: UnsafeMutableRawPointer,
                          _ byteCount: UInt32,
                          _ packetCount: UInt32,
                          _ data: UnsafeRawPointer,
                          _ packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>) {
    let parser = Unmanaged<Parser>.fromOpaque(context).takeUnretainedValue()
    let packetDescriptionsOrNil: UnsafeMutablePointer<AudioStreamPacketDescription>? = packetDescriptions
    let isCompressed = packetDescriptionsOrNil != nil
    os_log("%@ [bytes: %i, packets: %i, compressed: %@] - lines %d", log: Parser.loggerPacketCallback, type: .debug, #function, byteCount, packetCount, "\(isCompressed)", #line)
    
    /// At this point we should definitely have a data format
    guard let dataFormat = parser.dataFormat else {
        fatalError("Missing audio data format")
    }
    
    /// Iterate through the packets and store the data appropriately
    if isCompressed {
        for i in 0 ..< Int(packetCount) {
            let packetDescription = packetDescriptions[i]
            let packetStart = Int(packetDescription.mStartOffset)
            let packetSize = Int(packetDescription.mDataByteSize)
            let packetData = Data(bytes: data.advanced(by: packetStart), count: packetSize)
            parser.packets.append((packetData, packetDescription))
        }
    } else {
        let format = dataFormat.streamDescription.pointee
        let bytesPerPacket = Int(format.mBytesPerPacket)
        for i in 0 ..< Int(packetCount) {
            let packetStart = i * bytesPerPacket
            let packetSize = bytesPerPacket
            let packetData = Data(bytes: data.advanced(by: packetStart), count: packetSize)
            parser.packets.append((packetData, nil))
        }
    }
}

/// This extension just helps us print out the name of an `AudioFileStreamPropertyID`.
/// Purely for debugging and not essential to the main functionality of the parser.
extension AudioFileStreamPropertyID {
    
    var description: String {
        switch self {
        case kAudioFileStreamProperty_ReadyToProducePackets:
            return "Ready to produce packets"
        case kAudioFileStreamProperty_FileFormat:
            return "File format"
        case kAudioFileStreamProperty_DataFormat:
            return "Data format"
        case kAudioFileStreamProperty_AudioDataByteCount:
            return "Byte count"
        case kAudioFileStreamProperty_AudioDataPacketCount:
            return "Packet count"
        case kAudioFileStreamProperty_DataOffset:
            return "Data offset"
        case kAudioFileStreamProperty_BitRate:
            return "Bit rate"
        case kAudioFileStreamProperty_FormatList:
            return "Format list"
        case kAudioFileStreamProperty_MagicCookieData:
            return "Magic cookie"
        case kAudioFileStreamProperty_MaximumPacketSize:
            return "Max packet size"
        case kAudioFileStreamProperty_ChannelLayout:
            return "Channel layout"
        case kAudioFileStreamProperty_PacketToFrame:
            return "Packet to frame"
        case kAudioFileStreamProperty_FrameToPacket:
            return "Frame to packet"
        case kAudioFileStreamProperty_PacketToByte:
            return "Packet to byte"
        case kAudioFileStreamProperty_ByteToPacket:
            return "Byte to packet"
        case kAudioFileStreamProperty_PacketTableInfo:
            return "Packet table"
        case kAudioFileStreamProperty_PacketSizeUpperBound:
            return "Packet size upper bound"
        case kAudioFileStreamProperty_AverageBytesPerPacket:
            return "Average bytes per packet"
        case kAudioFileStreamProperty_InfoDictionary:
            return "Info dictionary"
        default:
            return "Unknown"
        }
    }
}
