import SwiftData
import Foundation

class DataComputationService: ObservableObject {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    /// Compute stats for a specific date
    @MainActor
    func computeStatsForDate(_ date: Date) async throws {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            // Delete existing stats for this date
            try deleteExistingStats(for: startOfDay)
            
            // Fetch raw logs for this date
            let appLogs = try fetchAppLogs(from: startOfDay, to: endOfDay)
            let keyLogs = try fetchKeyLogs(from: startOfDay, to: endOfDay)
            
            // Compute stats using existing service
            let appUsageStats = ChartDataService.usageTimeByApp(appLogs: appLogs)
            let keyPressSegments = ChartDataService.countKeyPressesByApp(appLogs: appLogs, keyLogs: keyLogs)
            
            // Create daily stats
            let dailyStats = DailyStats(
                date: startOfDay,
                totalKeyPresses: keyLogs.count,
                totalActiveTime: appUsageStats.reduce(0) { $0 + $1.duration }
            )
            
            // Add app usages
            for usage in appUsageStats {
                let keyPressCount = keyPressSegments.first { $0.appName == usage.appName }?.count ?? 0
                let dailyAppUsage = DailyAppUsage(
                    appName: usage.appName,
                    duration: usage.duration,
                    keyPresses: keyPressCount
                )
                dailyAppUsage.dailyStats = dailyStats
                dailyStats.appUsages.append(dailyAppUsage)
                context.insert(dailyAppUsage)
            }
            
            // Add key press segments
            for segment in keyPressSegments {
                let keyPressSegment = DailyKeyPressSegment(
                    appName: segment.appName,
                    count: segment.count
                )
                keyPressSegment.dailyStats = dailyStats
                dailyStats.keyPressSegments.append(keyPressSegment)
                context.insert(keyPressSegment)
            }
            
            context.insert(dailyStats)
            try context.save()
            
        } catch {
            throw error
        }
    }
    
    /// Compute stats for missing dates up to yesterday (not today)
    @MainActor
    func computeMissingStats() async throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
        let calendar = Calendar.current
        
        // Find earliest date we have raw logs
        let earliestAppLog = try context.fetch(
            FetchDescriptor<AppLog>(sortBy: [SortDescriptor(\.timestamp)])
        ).first
        
        let earliestKeyLog = try context.fetch(
            FetchDescriptor<KeyLog>(sortBy: [SortDescriptor(\.timestamp)])
        ).first
        
        guard let startDate = [earliestAppLog?.timestamp, earliestKeyLog?.timestamp]
            .compactMap({ $0 })
            .min() else { return }
        
        let startDay = calendar.startOfDay(for: startDate)
        
        // Get all dates that need computation (up to yesterday only)
        var currentDate = startDay
        var datesToCompute: [Date] = []
        
        while currentDate <= yesterdayStart {
            // Check if we already have stats for this date
            let hasStats = try hasComputedStats(for: currentDate)
            if !hasStats {
                datesToCompute.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Compute stats for missing dates
        for date in datesToCompute {
            try await computeStatsForDate(date)
        }
    }
    
    /// Check if we have computed stats for a date
    private func hasComputedStats(for date: Date) throws -> Bool {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate<DailyStats> { $0.date == startOfDay }
        )
        return try !context.fetch(descriptor).isEmpty
    }
    
    private func deleteExistingStats(for date: Date) throws {
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate<DailyStats> { $0.date == date }
        )
        let existing = try context.fetch(descriptor)
        for stats in existing {
            context.delete(stats)
        }
    }
    
    private func fetchAppLogs(from: Date, to: Date) throws -> [AppLog] {
        // Get the last app before the time window for carry-over
        var prevDescriptor = FetchDescriptor<AppLog>(
            predicate: #Predicate<AppLog> { $0.timestamp < from },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        prevDescriptor.fetchLimit = 1
        
        let descriptor = FetchDescriptor<AppLog>(
            predicate: #Predicate<AppLog> { $0.timestamp >= from && $0.timestamp < to },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        var logs = try context.fetch(descriptor)
        
        // Add carry-over if exists
        if let prevLog = try context.fetch(prevDescriptor).first {
            let carryOver = AppLog(timestamp: from, appName: prevLog.appName)
            logs.insert(carryOver, at: 0)
        } else {
            let carryOver = AppLog(timestamp: from, appName: "Pre-Big Bang")
            logs.insert(carryOver, at: 0)
        }
        
        return logs
    }
    
    private func fetchKeyLogs(from: Date, to: Date) throws -> [KeyLog] {
        let descriptor = FetchDescriptor<KeyLog>(
            predicate: #Predicate<KeyLog> { $0.timestamp >= from && $0.timestamp < to },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try context.fetch(descriptor)
    }
}
