//
//  PersistenceController.swift
//  TrackMe
//
//  Created by Quang Huy on 07/05/2025.
//

import SwiftData
import Foundation

struct AutoLogController {
    static let shared = AutoLogController()

    let container: ModelContainer

    init() {
        let schema = Schema([
            KeyLog.self, 
            AppLog.self, 
            DailyStats.self, 
            DailyAppUsage.self, 
            DailyKeyPressSegment.self, 
            ComputationJob.self
        ])
        let url = URL.applicationSupportDirectory.appending(path: "autoLog.store")
        let configuration = ModelConfiguration(schema: schema, url: url)
        container = try! ModelContainer(for: schema, configurations: [configuration])
    }
    
    @MainActor
    func deleteAllData() {
        let context = container.mainContext
        do {
            let keyLogs = try context.fetch(FetchDescriptor<KeyLog>())
            for keyLog in keyLogs {
                context.delete(keyLog)
            }
            let appLogs = try context.fetch(FetchDescriptor<AppLog>())
            for appLog in appLogs {
                context.delete(appLog)
            }
            try context.save()
        } catch {
            print("Error deleting data: \(error)")
        }
    }
}
