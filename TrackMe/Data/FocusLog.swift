//
//  FocusLog.swift
//  TrackMe
//
//  Created by Quang Huy on 08/05/2025.
//

import Foundation
import SwiftData

@Model
final class FocusLog {
    var timestamp: Date
    var focusName: String
    
    init(timestamp: Date = Date(), focusName: String) {
        self.timestamp = timestamp
        self.focusName = focusName
    }
}
