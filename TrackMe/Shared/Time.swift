//
//  Time.swift
//  TrackMe
//
//  Created by Quang Huy on 15/05/2025.
//

import Foundation

enum Time {
    
    /// Formats a duration in seconds to a human-readable string
    /// - Parameter seconds: The duration in seconds
    /// - Returns: Formatted string like "2h 30m" or "45s"
    static func formatDuration(seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return [
            h > 0 ? "\(h)h" : nil,
            m > 0 ? "\(m)m" : nil,
            h == 0 && m == 0 && s > 0 ? "\(s)s" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}
