//
//  DownloadingState.swift
//  PitchShifter
//
//  Created by David Solis on 4/4/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import Foundation

/// The various states of a download request.
///
/// - notStarted: The download has not started yet
/// - started: The download has yet to start
/// - paused: The download is paused
/// - completed: The download has completed
/// - stopped: The download has been stopped/cancelled
enum DownloadingState: String {
    case notStarted
    case started
    case paused
    case completed
    case stopped
}
