//
//  Downloading.swift
//  PitchShifter
//
//  Created by David Solis on 4/4/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import Foundation

protocol Downloading: class {
    // MARK: - Properties
    
    /// A receiver implementing the `DownloadingDelegate` to receive state change, completion, and progress events from the `Downloading` instance
    var delegate: DownloadingDelegate? { get set }
    
    /// A completion block for when the contents of the download are fully downloaded.
    var completionHandler: ((Error?) -> Void)? { get set }
    
    /// The current progress of the downloader. Ranges from 0.0 - 1.0, default is 0.0
    var progress: Double { get }
    
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

/// The `DownloadingDelegate` provides an interface for responding to changes to a `Downloader` instance.
/// These include whenever the download state changes, when the download has completed (with or without an error), and when the downloader has received data.
protocol DownloadingDelegate: class {
    
    /// Triggered when a `Downloader` instance has changed its `Downloading` state during an existing download operation.
    ///
    /// - Parameters:
    ///   - download: The current `Downloading` instance
    ///   - state: The new `DownloadingState` the `Downloading` has transitioned to
    func download(_ download: Downloading, changedState state: DownloadingState)
    
    /// Triggered when a `Downloading` instance has fully completed its request.
    ///
    /// - Parameters:
    ///   - download: The current `Downloading` instance
    ///   - error: An optional `Error` if the download failed to complete. If there were no errors then this will be nil.
    func download(_ download: Downloading, completedWithError error: Error?)
    
    /// Triggered periodically whenever the `Downloading` instance has more data. In addition, this method provides the current progress of the overall operation as a Double.
    ///
    /// - Parameters:
    ///   - download: The current `Downloading` instance
    ///   - data: A `Data` instance representing the current binary data
    ///   - progress: A `Double` ranging from 0.0 - 1.0 representing the progress of the overall download operation.
    func download(_ download: Downloading, didReceiveData data: Data, progress: Double)
}
