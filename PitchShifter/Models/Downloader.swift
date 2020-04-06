//
//  Downloader.swift
//  PitchShifter
//
//  Created by David Solis on 3/19/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import Foundation

class Downloader: NSObject, Downloading {
    
    // MARK: - Properties
    
    /// The `URLSession` currently being used as the HTTP/HTTPS implementation for the downloader.
    private lazy var session: URLSession = {
        return URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    /// A `URLSessionDataTask` representing the data operation for the current `URL`.
    private var task: URLSessionDataTask?
    var delegate: DownloadingDelegate?
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
    var state: DownloadingState = .notStarted {
        didSet {
            delegate?.download(self, changedState: state)
        }
    }
    var progress: Double = 0
    var progressHandler: ((Data, Double) -> Void)?
    var completionHandler: ((Error?) -> Void)?
    /// A `Int` representing the total amount of bytes for the entire file
    var totalBytesCount: Int = 0
    /// A `Int` representing the total amount of bytes received
    var totalBytesReceived: Int = 0
    
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

extension Downloader: URLSessionDelegate {
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
