//
//  AppLog.swift
//  TrackMe
//
//  Created by Quang Huy on 07/05/2025.
//

import Foundation
import SwiftData

@Model
final class AppLog {
    var timestamp: Date
    var appName: String
    
    init(timestamp: Date = Date(), appName: String) {
        self.timestamp = timestamp
        self.appName = appName
    }
}
