//
//  DownloadingDelegate.swift
//  PitchShifter
//
//  Created by David Solis on 4/5/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import os.log
import Foundation

extension Streamer: DownloadingDelegate {

    func download(_ download: Downloading, completedWithError error: Error?) {
        if let error = error, let url = download.url {
            os_log("%@ [error: %@] - line %d", log: Streamer.logger, type: .debug, #function, error.localizedDescription, #line)
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.streamer(self, failedDownloadWithError: error, forURL: url)
            }
        } else {
            fatalError("Completed with error")
        }
    }
    
    func download(_ download: Downloading, changedState downloadState: DownloadingState) {
        os_log("%@ [state: %@] - line %d", log: Streamer.logger, type: .debug, #function, downloadState.rawValue, #line)
    }
    
    func download(_ download: Downloading, didReceiveData data: Data, progress: Double) {
        os_log("%@ - line %d", log: Streamer.logger, type: .debug, #function, #line)
        
        guard let parser = parser else {
            os_log("Expected parser, bail - line %d", log: Streamer.logger, type: .error, #line)
            return
        }
        
        /// Parse the incoming audio into packets
        do {
            try parser.parse(data: data)
        } catch {
            os_log("[error: Failed to parse] - line %d", log: Streamer.logger, type: .error, #line)
            print(error.localizedDescription)
            return
        }
        
        /// Once there's enough data to start producing packets we can use the data format
        if reader == nil, let _ = parser.dataFormat {
            do {
                reader = try Reader(parser: parser, readFormat: readFormat)
            } catch {
                os_log("[error: Failed to create reader] - line %d", log: Streamer.logger, type: .error, #line)
                print(error.localizedDescription)
                return
            }
        }
        
        /// Update the progress UI
        DispatchQueue.main.async { [weak self] in
            // Notify the delegate of the new progress value of the download
            self?.notifyDownloadProgress(Float(progress))
            
            // Check if we have the duration
            self?.handleDurationUpdate()
        }
    }
}
