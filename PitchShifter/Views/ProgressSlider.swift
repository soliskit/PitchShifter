//
//  ProgressSlider.swift
//  PitchShifter
//
//  Created by David Solis on 4/6/20.
//  Copyright © 2020 David Solis. All rights reserved.
//

import UIKit

class ProgressSlider: UISlider {
    
    // MARK: - Properties
    
    /// A `UIProgressView` used to display the track progress layer
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    /// A `Float` representing the progress value
    @IBInspectable var progress: Float {
        get {
            return progressView.progress
        }
        set {
            progressView.progress = newValue
        }
    }
    
    /// A `UIColor` representing the progress view's track tint color (right region)
    @IBInspectable public var progressTrackTintColor: UIColor {
        get {
            return progressView.trackTintColor ?? .white
        }
        set {
            progressView.trackTintColor = newValue
        }
    }
    
    /// A `UIColor` representing the progress view's progress tint color (left region)
    @IBInspectable public var progressProgressTintColor: UIColor {
        get {
            return progressView.progressTintColor ?? .blue
        }
        set {
            progressView.progressTintColor = newValue
        }
    }
    
    // MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    // MARK: - Methods
    
    func setup() {
        insertSubview(progressView, at: 0)
        
        let trackFrame = super.trackRect(forBounds: bounds)
        var center = CGPoint(x: 0, y: 0)
        center.y = floor(frame.height / 2 + progressView.frame.height / 2)
        progressView.center = center
        progressView.frame.origin.x = 2
        progressView.frame.size.width = trackFrame.width - 4
        progressView.autoresizingMask = [.flexibleWidth]
        progressView.clipsToBounds = true
        progressView.layer.cornerRadius = 2
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var result = super.trackRect(forBounds: bounds)
        result.size.height = 0.01
        return result
    }

    /// Sets the progress on the progress view.
    ///
    /// - Parameters:
    ///   - progress: A float representing the progress value (0 - 1)
    ///   - animated: A bool indicating whether the new progress value is animated
    func setProgress(_ progress: Float, animated: Bool) {
        progressView.setProgress(progress, animated: animated)
    }
}

extension TimeInterval {
    // TODO: - Replace with DateComponentsFormatter
    /// Converts a `TimeInterval` into a MM:SS formatted string.
    ///
    /// - Returns: A `String` representing the MM:SS formatted representation of the time interval.
    func toMMSS() -> String {
        let ts = Int(self)
        let s = ts % 60
        let m = (ts / 60) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
