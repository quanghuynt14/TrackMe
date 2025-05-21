//
//  LoggingManager.swift
//  TrackMe
//
//  Created by Quang Huy on 07/05/2025.
//

import Cocoa
import SwiftData

final class LoggingManager: ObservableObject {
    let keyLogger: KeyLogger
    let appLogger: AppLogger

    init(autoLogContext: ModelContext, focusContext: ModelContext) {
        keyLogger = KeyLogger(context: autoLogContext)
        appLogger = AppLogger(autoLogContext: autoLogContext, focusContext: focusContext)
    }
}
