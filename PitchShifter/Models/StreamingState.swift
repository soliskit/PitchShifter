//
//  StreamingState.swift
//  PitchShifter
//
//  Created by David Solis on 4/5/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import Foundation

/// The various playback states of a `Streaming`.
/// - playing: Audio playback is playing
/// - paused: Audio playback is paused
/// - stopped: Audio playback and download operations are all stopped
enum StreamingState: String {
    case playing
    case paused
    case stopped
}
