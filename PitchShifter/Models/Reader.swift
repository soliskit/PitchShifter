//
//  Reader.swift
//  PitchShifter
//
//  Created by David Solis on 4/5/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import AVFoundation

/// The `Reader` is a concrete implementation of the `Reading` protocol and is intended to provide the audio data provider for an `AVAudioEngine`.
/// The `parser` property provides a `Parseable` that handles converting binary audio data into audio packets in whatever the original file's format was
/// (MP3, AAC, WAV, etc). The reader handles converting the audio data coming from the parser to a LPCM format that can be used in the context of
/// `AVAudioEngine` since the `AVAudioPlayerNode` requires we provide `AVAudioPCMBuffer` in the `scheduleBuffer` methods.
class Reader: Reading {
    
    // MARK: - Reading props
    
    var currentPacket: AVAudioPacketCount = 0
    let parser: Parsing
    let readFormat: AVAudioFormat
    
    // MARK: - Properties
    
    // TODO: - Use AVAudioConverter to convert audio file formats
    /// An `AudioConverterRef` used to do the conversion from the source format of the `parser` (i.e. the `sourceFormat`) to the read destination
    /// (i.e. the `destinationFormat`). This is provided by the Audio Conversion Services (I prefer it to the `AVAudioConverter`)
    var converter: AudioConverterRef? = nil
    
    /// A `DispatchQueue` used to ensure any operations we do changing the current packet index is thread-safe
    let queue = DispatchQueue(label: "co.peaking.pitch_shifter")
    
    // MARK: - Lifecycle
    
    deinit {
        guard AudioConverterDispose(converter!) == noErr else {
            fatalError("Failed to dispose of audio converter")
        }
    }
    
    required init(parser: Parsing, readFormat: AVAudioFormat) throws {
        self.parser = parser
        
        guard let dataFormat = parser.dataFormat else {
            throw ReaderError.parserMissingDataFormat
        }

        let sourceFormat = dataFormat.streamDescription
        let commonFormat = readFormat.streamDescription
        let result = AudioConverterNew(sourceFormat, commonFormat, &converter)
        guard result == noErr else {
            throw ReaderError.unableToCreateConverter(result)
        }
        self.readFormat = readFormat
    }
    
    // MARK: - Methods
    
    func read(_ frames: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        let framesPerPacket = readFormat.streamDescription.pointee.mFramesPerPacket
        var packets = frames / framesPerPacket
        
        /// Allocate a buffer to hold the target audio data in the Read format
        guard let buffer = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: frames) else {
            throw ReaderError.failedToCreatePCMBuffer
        }
        buffer.frameLength = frames
        
        // Try to read the frames from the parser
        try queue.sync {
            let context = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
            let status = AudioConverterFillComplexBuffer(converter!, ReaderConverterCallback, context, &packets, buffer.mutableAudioBufferList, nil)
            guard status == noErr else {
                switch status {
                case ReaderMissingSourceFormatError:
                    throw ReaderError.parserMissingDataFormat
                case ReaderReachedEndOfDataError:
                    throw ReaderError.reachedEndOfFile
                case ReaderNotEnoughDataError:
                    throw ReaderError.notEnoughData
                default:
                    throw ReaderError.converterFailed(status)
                }
            }
        }
        return buffer
    }
    
    func seek(_ packet: AVAudioPacketCount) throws {
        queue.sync {
            currentPacket = packet
        }
    }
}

func ReaderConverterCallback(_ converter: AudioConverterRef,
                             _ packetCount: UnsafeMutablePointer<UInt32>,
                             _ ioData: UnsafeMutablePointer<AudioBufferList>,
                             _ outPacketDescriptions: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
                             _ context: UnsafeMutableRawPointer?) -> OSStatus {
    let reader = Unmanaged<Reader>.fromOpaque(context!).takeUnretainedValue()
    
    //
    // Make sure we have a valid source format so we know the data format of the parser's audio packets
    //
    guard let sourceFormat = reader.parser.dataFormat else {
        return ReaderMissingSourceFormatError
    }
    
    //
    // Check if we've reached the end of the packets. We have two scenarios:
    //     1. We've reached the end of the packet data and the file has been completely parsed
    //     2. We've reached the end of the data we currently have downloaded, but not the file
    //
    let packetIndex = Int(reader.currentPacket)
    let packets = reader.parser.packets
    let isEndOfData = packetIndex >= packets.count - 1
    if isEndOfData {
        if reader.parser.isParsingComplete {
            packetCount.pointee = 0
            return ReaderReachedEndOfDataError
        } else {
            return ReaderNotEnoughDataError
        }
    }
    
    //
    // Copy data over (note we've only processing a single packet of data at a time)
    //
    let packet = packets[packetIndex]
    var data = packet.0
    let dataCount = data.count
    ioData.pointee.mNumberBuffers = 1
    ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: dataCount, alignment: 0)
    _ = data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
        memcpy((ioData.pointee.mBuffers.mData?.assumingMemoryBound(to: UInt8.self))!, bytes, dataCount)
    }
    ioData.pointee.mBuffers.mDataByteSize = UInt32(dataCount)
    
    //
    // Handle packet descriptions for compressed formats (MP3, AAC, etc)
    //
    let sourceFormatDescription = sourceFormat.streamDescription.pointee
    if sourceFormatDescription.mFormatID != kAudioFormatLinearPCM {
        if outPacketDescriptions?.pointee == nil {
            outPacketDescriptions?.pointee = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: 1)
        }
        outPacketDescriptions?.pointee?.pointee.mDataByteSize = UInt32(dataCount)
        outPacketDescriptions?.pointee?.pointee.mStartOffset = 0
        outPacketDescriptions?.pointee?.pointee.mVariableFramesInPacket = 0
    }
    packetCount.pointee = 1
    reader.currentPacket = reader.currentPacket + 1
    
    return noErr;
}
