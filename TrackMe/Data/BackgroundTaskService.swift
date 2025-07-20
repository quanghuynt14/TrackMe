import Foundation
import SwiftData

class BackgroundTaskService {
    private let context: ModelContext
    private let computationService: DataComputationService
    private var midnightTimer: Timer?
    
    init(context: ModelContext) {
        self.context = context
        self.computationService = DataComputationService(context: context)
        setupMidnightTimer()
    }
    
    private func setupMidnightTimer() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next midnight
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let nextMidnight = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        let timeInterval = nextMidnight.timeIntervalSince(now)
        
        // Schedule timer for midnight
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.performMidnightComputation()
                self?.scheduleNextMidnightTimer()
            }
        }
    }
    
    private func scheduleNextMidnightTimer() {
        // Schedule for next day at midnight
        midnightTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performMidnightComputation()
            }
        }
    }
    
    @MainActor
    private func performMidnightComputation() async {
        do {
            // Compute yesterday's stats (which is now complete)
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            try await computationService.computeStatsForDate(yesterday)
            
            // Also compute any missing historical stats (but not today)
            try await computationService.computeMissingStats()
            
            print("✅ Midnight computation completed for yesterday: \(yesterday)")
        } catch {
            print("❌ Midnight computation failed: \(error)")
        }
    }
    
    deinit {
        midnightTimer?.invalidate()
    }
}
