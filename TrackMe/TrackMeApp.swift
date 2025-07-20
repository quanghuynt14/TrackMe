//
//  TrackMeApp.swift
//  TrackMe
//
//  Created by Quang Huy on 30/04/2025.
//

import SwiftUI
import SwiftData

@main
struct TrackMeApp: App {
    let autoLogController = AutoLogController.shared
    let focusController = FocusController.shared
    private let backgroundTaskService: BackgroundTaskService
    
    @StateObject private var loggingManager: LoggingManager

    init() {
        let autoLogContext = autoLogController.container.mainContext
        let focusContext = focusController.container.mainContext
        
        // Initialize background service
        self.backgroundTaskService = BackgroundTaskService(context: autoLogContext)
        
        _loggingManager = StateObject(wrappedValue: LoggingManager(
            autoLogContext: autoLogContext,
            focusContext: focusContext)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
//                .task{ autoLogController.deleteAllData()} // DELETE ALL DATA
                .environmentObject(loggingManager)
                .modelContainer(autoLogController.container)
        }
        
        Settings {
            SettingsView(context: focusController.container.mainContext)
        }
    }
}

