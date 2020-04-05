//
//  DownloadClient.swift
//  PitchShifter
//
//  Created by David Solis on 3/19/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import Foundation

class DownloadClient: NSObject, Downloading {
    
    // MARK: - Properties
    var delegate: DownloadingDelegate?
    var completionHandler: ((Error?) -> Void)?
    var progressHandler: ((Data, Double) -> Void)?
    var progress: Double = 0
    
    var state: DownloadingState = .notStarted {
        didSet {
            delegate?.download(self, changedState: state)
        }
    }
    
    var url: URL? {
        didSet {
            if state == .started {
                stop()
            }
            if let url = url {
                progress = 0.0
                state = .notStarted
                totalBytesCount = 0
                totalBytesReceived = 0
                task = session.dataTask(with: url)
            } else {
                task = nil
            }
        }
    }

    /// The `URLSession` currently being used as the HTTP/HTTPS implementation for the downloader.
    private lazy var session: URLSession = {
        return URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    /// A `URLSessionDataTask` representing the data operation for the current `URL`.
    private var task: URLSessionDataTask?

    /// A `Int` representing the total amount of bytes received
    var totalBytesReceived: Int = 0

    /// A `Int` representing the total amount of bytes for the entire file
    var totalBytesCount: Int = 0
    
    // MARK: - Downloading Protocol
    
    func start() {
        guard let task = task else {
            fatalError("Task does not exist")
        }
        
        switch state {
            case .completed, .started:
                return
            default:
                state = .started
                task.resume()
        }
    }
    
    func pause() {
        guard let task = task else {
            fatalError("Task does not exist")
        }
        guard state == .started else {
            return
        }
        
        state = .paused
        task.suspend()
    }
    
    func stop() {
        guard let task = task else {
            fatalError("Task does not exist")
        }
        guard state == .started else {
            return
        }
        
        state = .stopped
        task.cancel()
    }
}

extension DownloadClient: URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        totalBytesCount = Int(response.expectedContentLength)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        totalBytesReceived += data.count
        progress = Double(totalBytesReceived) / Double(totalBytesCount)
        delegate?.download(self, didReceiveData: data, progress: progress)
        progressHandler?(data, progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        state = .completed
        delegate?.download(self, completedWithError: error)
        completionHandler?(error)
    }
}

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

/// The `DownloadingDelegate` provides an interface for responding to changes to a `DownloadClient` instance.
/// These include whenever the download state changes, when the download has completed (with or without an error), and when the downloader has received data.
protocol DownloadingDelegate: class {
    
    /// Triggered when a `DownloadClient` instance has changed its `Downloading` state during an existing download operation.
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
