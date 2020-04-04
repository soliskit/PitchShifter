//
//  DownloadClient.swift
//  PitchShifter
//
//  Created by David Solis on 3/19/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import Foundation

protocol Downloading: class {
    // MARK: - Properties
    
    /// A receiver implementing the `DownloadingDelegate` to receive state change, completion, and progress events from the `Downloading` instance
    var delegate: DownloadingDelegate? { get set }
    
    /// The current progress of the downloader. Ranges from 0.0 - 1.0, default is 0.0
    var progress: Float { get }
    
    /// The current state of the downloader. See `DownloadingState` for the different prossible states
    var state: DownloadingState { get }
    
    /// A `URL` representing the current URL the downloader is fetching. This is an optional because this protocol is designed to allow classes implementing the `Downloading` protocol to be used as singeltons for many different URLS so a common cache can be used to to redownloading the same resources
    var url: URL? { get set }
    
    // MARK:- Methods
    
    /// Starts the downloader
    func start()
    
    /// Pauses the downloader
    func pause()
    
    /// Stops and/or aborts the downloader. This should invalidate all cache data under the hood
    func stop()
}

protocol DownloadingDelegate: class {
    func download(_ download: Downloading, changedState state: DownloadingState)
    func download(_ download: Downloading, completedWithError error: Error?)
    func download(_ download: Downloading, didReceiveData data: Data, progress: Float)
}

enum DownloadingState: String {
    case notStarted
    case started
    case paused
    case completed
    case stopped
}
