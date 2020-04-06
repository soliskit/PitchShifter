//
//  DownloadingDelegate.swift
//  PitchShifter
//
//  Created by David Solis on 4/5/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import Foundation

extension Streamer: DownloadingDelegate {

    func download(_ download: Downloading, completedWithError error: Error?) {
        if let error = error, let url = download.url {
            print(error.localizedDescription)
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.streamer(self, failedDownloadWithError: error, forURL: url)
            }
        }
    }
    
    func download(_ download: Downloading, changedState downloadState: DownloadingState) {
        print(downloadState.rawValue)
    }
    
    func download(_ download: Downloading, didReceiveData data: Data, progress: Double) {
        guard let parser = parser else {
            print("Expected parser, bail...")
            return
        }
        
        /// Parse the incoming audio into packets
        do {
            try parser.parse(data: data)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        /// Once there's enough data to start producing packets we can use the data format
        if reader == nil, let _ = parser.dataFormat {
            do {
                reader = try Reader(parser: parser, readFormat: readFormat)
            } catch {
                fatalError("Failed to create reader: \(error.localizedDescription)")
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
