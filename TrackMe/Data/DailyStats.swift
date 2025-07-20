import SwiftData
import Foundation

@Model
class DailyStats {
    @Attribute(.unique) var date: Date // Start of day
    var totalKeyPresses: Int
    var totalActiveTime: TimeInterval
    var lastComputedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var appUsages: [DailyAppUsage]
    @Relationship(deleteRule: .cascade) var keyPressSegments: [DailyKeyPressSegment]
    
    init(date: Date, totalKeyPresses: Int = 0, totalActiveTime: TimeInterval = 0) {
        self.date = Calendar.current.startOfDay(for: date)
        self.totalKeyPresses = totalKeyPresses
        self.totalActiveTime = totalActiveTime
        self.lastComputedAt = Date()
        self.appUsages = []
        self.keyPressSegments = []
    }
}

@Model
class DailyAppUsage {
    var appName: String
    var duration: TimeInterval
    var keyPresses: Int
    
    // Back reference
    var dailyStats: DailyStats?
    
    init(appName: String, duration: TimeInterval, keyPresses: Int) {
        self.appName = appName
        self.duration = duration
        self.keyPresses = keyPresses
    }
}

@Model
class DailyKeyPressSegment {
    var appName: String
    var count: Int
    
    // Back reference
    var dailyStats: DailyStats?
    
    init(appName: String, count: Int) {
        self.appName = appName
        self.count = count
    }
}

@Model
class ComputationJob {
    @Attribute(.unique) var date: Date
    var status: ComputationStatus
    var createdAt: Date
    var completedAt: Date?
    var errorMessage: String?
    
    init(date: Date, status: ComputationStatus = .pending) {
        self.date = Calendar.current.startOfDay(for: date)
        self.status = status
        self.createdAt = Date()
    }
}

enum ComputationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case computing = "computing"
    case completed = "completed"
    case failed = "failed"
}
