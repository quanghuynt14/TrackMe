//
//  KeyLog.swift
//  TrackMe
//
//  Created by Quang Huy on 07/05/2025.
//

import Foundation
import SwiftData

@Model
final class KeyLog {
    var timestamp: Date
    var keyCode: Int64

    init(timestamp: Date = Date(), keyCode: Int64) {
        self.timestamp = timestamp
        self.keyCode = keyCode
    }
}
