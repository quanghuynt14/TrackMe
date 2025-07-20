//
//  ContentView.swift
//  TrackMe
//
//  Created by Quang Huy on 30/04/2025.
//

import Foundation
import SwiftUI
import Charts
import SwiftData
import CryptoKit

// MARK: — Models
struct AppSegmentCount: Identifiable {
    let id = UUID()
    let appName: String
    let count: Int
}

struct KeyPressSummary: Identifiable {
    let id = UUID()
    let day: Date  // represents start of day interval
    let count: Int    // number of key presses in that day
}

struct AppUsage: Identifiable {
    let id = UUID()
    let appName: String
    let duration: TimeInterval  // seconds
}


// MARK: — TimeFrame Definition
enum TimeFrame: String, CaseIterable, Identifiable {
    case day = "Day", week = "Week", month = "Month"
    case quarter = "Quarter", halfYear = "Half-Year", year = "Year", all = "All"
    var id: String { rawValue }
    var title: String { rawValue }

    private var calendar: Calendar { .current }

    func startDate() -> Date? {
        let now = Date()
        switch self {
        case .day:
            // 00:00 today
            return calendar.startOfDay(for: now)

        case .week:
            // Find this week's Monday, then strip to midnight
            let weekday = calendar.component(.weekday, from: now)
            let daysSinceMonday = (weekday + 5) % 7
            let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: now)!
            return calendar.startOfDay(for: monday)

        case .month:
            // First day of this month at 00:00
            return calendar.dateInterval(of: .month, for: now)!.start

        case .quarter:
            // Build the first month of current quarter at 00:00
            let comps = calendar.dateComponents([.year, .month], from: now)
            let startMonth = ((comps.month! - 1) / 3) * 3 + 1
            return calendar.date(from:
                DateComponents(year: comps.year, month: startMonth, day: 1)
            )!

        case .halfYear:
            // Either Jan 1 or Jul 1 at 00:00
            let comps = calendar.dateComponents([.year, .month], from: now)
            let startMonth = comps.month! <= 6 ? 1 : 7
            return calendar.date(from:
                DateComponents(year: comps.year, month: startMonth, day: 1)
            )!

        case .year:
            // Jan 1 of this year at 00:00
            let year = calendar.component(.year, from: now)
            return calendar.date(from:
                DateComponents(year: year, month: 1, day: 1)
            )!

        case .all:
            return nil
        }
    }

    /// Label for UI
    var displayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        guard let start = startDate() else { return "All time" }
        switch self {
        case .day: return formatter.string(from: start)
        default:
            return formatter.string(from: start)
        }
    }
}

// MARK: — Data Service
struct ChartDataService {
    static func countKeyPressesByApp(appLogs: [AppLog], keyLogs: [KeyLog]) -> [AppSegmentCount] {
        var counts = [String: Int]()
        var index = 0

        for key in keyLogs {
            while index < appLogs.count - 1 && appLogs[index + 1].timestamp <= key.timestamp {
                index += 1
            }
            let app = appLogs[index].appName
            counts[app, default: 0] += 1
        }

        return counts.map { AppSegmentCount(appName: $0.key, count: $0.value) }
                     .sorted(by: { $0.count > $1.count })
    }

    /// Count key presses per day
    static func countKeyPressesPerDay(keyLogs: [KeyLog]) -> [KeyPressSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: keyLogs) { event in
            calendar.startOfDay(for: event.timestamp)  // round down to start of day
        }
        return grouped.map { day, events in
            KeyPressSummary(day: day, count: events.count)
        }
        .sorted(by: { $0.day < $1.day })
    }
    
    /// Compute total usage time per app by walking the sequence of AppLog entries.
    static func usageTimeByApp(appLogs: [AppLog]) -> [AppUsage] {
        guard !appLogs.isEmpty else { return [] }

        var totals = [String: TimeInterval]()

        for (current, next) in zip(appLogs, appLogs.dropFirst()) {
            let interval = next.timestamp.timeIntervalSince(current.timestamp)
            totals[current.appName, default: 0] += interval
        }
    
        if let last = appLogs.last {
            let end: Date
            if Calendar.current.isDateInToday(last.timestamp) {
                end = Date()
            } else {
                end = Calendar.current.date(
                    bySettingHour: 23,
                    minute: 59,
                    second: 59,
                    of: last.timestamp
                )!
            }
            
            let interval = end.timeIntervalSince(last.timestamp)
            
            totals[last.appName, default: 0] += max(0, interval)
            
        }

        return totals.map { AppUsage(appName: $0.key, duration: $0.value) }
                     .sorted { $0.duration > $1.duration }
    }
}

// MARK: — ViewModel
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var selectedFrame: TimeFrame = .day
    @Published var currentDay: Date = Date()
    @Published var segmentCounts: [AppSegmentCount] = []
    @Published var keySummaries: [KeyPressSummary] = []
    @Published var usageStats: [AppUsage] = []
    @Published var yearlyKeySummaries: [KeyPressSummary] = [] // For GitHub-style chart
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false

    private var segmentCache = [TimeFrameKey: [AppSegmentCount]]()
    private var summaryCache = [TimeFrameKey: [KeyPressSummary]]()
    private var usageCache   = [TimeFrameKey: [AppUsage]]()
    private var yearlyCache: [KeyPressSummary]? // Cache for yearly data
    
    private var context: ModelContext
    private let computationService: DataComputationService

    init(context: ModelContext) {
        self.context = context
        self.computationService = DataComputationService(context: context)
        Task { 
            await loadYearlyData()
            await loadData() 
        }
    }

    func loadData() async {
        if selectedFrame == .day {
            await loadDayData()
        } else {
            await loadAggregatedData()
        }
    }
    
    private func loadDayData() async {
        let targetDate = Calendar.current.startOfDay(for: currentDay)
        
        // Check cache first
        let key = TimeFrameKey(frame: .day, day: targetDate)
        if let cachedSegs = segmentCache[key],
           let cachedSumm = summaryCache[key],
           let cachedUsages = usageCache[key] {
            await MainActor.run {
                segmentCounts = cachedSegs
                keySummaries = cachedSumm
                usageStats = cachedUsages
            }
            return
        }
        
        // Try to get pre-computed stats from database
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate<DailyStats> { $0.date == targetDate }
        )
        
        do {
            if let dailyStats = try context.fetch(descriptor).first {
                // Use pre-computed data
                let usages = dailyStats.appUsages.map { 
                    AppUsage(appName: $0.appName, duration: $0.duration) 
                }.sorted { $0.duration > $1.duration }
                
                let segments = dailyStats.keyPressSegments.map {
                    AppSegmentCount(appName: $0.appName, count: $0.count)
                }.sorted { $0.count > $1.count }
                
                let summary = [KeyPressSummary(day: targetDate, count: dailyStats.totalKeyPresses)]
                
                // Cache the results
                segmentCache[key] = segments
                summaryCache[key] = summary
                usageCache[key] = usages
                
                await MainActor.run {
                    usageStats = usages
                    segmentCounts = segments
                    keySummaries = summary
                }
            } else {
                // No pre-computed data available - compute and store for first time
                try await computationService.computeStatsForDate(targetDate)
                await loadDayData() // Reload with computed data
            }
        } catch {
            print("Error loading day data: \(error)")
            // Show empty data rather than fallback
            await MainActor.run {
                usageStats = []
                segmentCounts = []
                keySummaries = []
            }
        }
    }
    
    private func loadAggregatedData() async {
        guard let startDate = selectedFrame.startDate() else {
            // Load all data - get all available daily stats
            await loadAllTimeData()
            return
        }
        
        // Check cache first
        let key = TimeFrameKey(frame: selectedFrame, day: nil)
        if let cachedSegs = segmentCache[key],
           let cachedSumm = summaryCache[key],
           let cachedUsages = usageCache[key] {
            await MainActor.run {
                segmentCounts = cachedSegs
                keySummaries = cachedSumm
                usageStats = cachedUsages
            }
            return
        }
        
        let endDate = Date()
        let startOfDay = Calendar.current.startOfDay(for: startDate)
        let endOfDay = Calendar.current.startOfDay(for: endDate)
        
        // Get all daily stats in range
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate<DailyStats> { $0.date >= startOfDay && $0.date <= endOfDay },
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            let dailyStats = try context.fetch(descriptor)
            // Use whatever stored data we have (even if empty)
            await aggregateAndDisplay(dailyStats: dailyStats, cacheKey: key)
        } catch {
            print("Error fetching aggregated data: \(error)")
            // Show empty data
            await MainActor.run {
                usageStats = []
                segmentCounts = []
                keySummaries = []
            }
        }
    }
    
    private func loadAllTimeData() async {
        // Check cache first
        let key = TimeFrameKey(frame: .all, day: nil)
        if let cachedSegs = segmentCache[key],
           let cachedSumm = summaryCache[key],
           let cachedUsages = usageCache[key] {
            await MainActor.run {
                segmentCounts = cachedSegs
                keySummaries = cachedSumm
                usageStats = cachedUsages
            }
            return
        }
        
        // For "All" time frame, get all available daily stats
        let descriptor = FetchDescriptor<DailyStats>(
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            let allDailyStats = try context.fetch(descriptor)
            // Use all the stored data we have (even if empty)
            await aggregateAndDisplay(dailyStats: allDailyStats, cacheKey: key)
        } catch {
            print("Error fetching all-time data: \(error)")
            // Show empty data
            await MainActor.run {
                usageStats = []
                segmentCounts = []
                keySummaries = []
            }
        }
    }
    
    private func aggregateAndDisplay(dailyStats: [DailyStats], cacheKey: TimeFrameKey) async {
        var appUsageMap: [String: TimeInterval] = [:]
        var appKeyPressMap: [String: Int] = [:]
        var dailySummaries: [KeyPressSummary] = []
        
        for stats in dailyStats {
            dailySummaries.append(KeyPressSummary(day: stats.date, count: stats.totalKeyPresses))
            
            for usage in stats.appUsages {
                appUsageMap[usage.appName, default: 0] += usage.duration
                appKeyPressMap[usage.appName, default: 0] += usage.keyPresses
            }
        }
        
        let usages = appUsageMap.map { 
            AppUsage(appName: $0.key, duration: $0.value) 
        }.sorted { $0.duration > $1.duration }
        
        let segments = appKeyPressMap.map {
            AppSegmentCount(appName: $0.key, count: $0.value)
        }.sorted { $0.count > $1.count }
        
        let sortedSummaries = dailySummaries.sorted { $0.day < $1.day }
        
        // Cache the results
        segmentCache[cacheKey] = segments
        summaryCache[cacheKey] = sortedSummaries
        usageCache[cacheKey] = usages
        
        await MainActor.run {
            usageStats = usages
            segmentCounts = segments
            keySummaries = sortedSummaries
        }
    }
    
    func shiftCurrentDay(by days: Int) {
        currentDay = Calendar.current.date(byAdding: .day, value: days, to: currentDay)!
        Task { await loadData() }
    }
    
    func refreshData() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        defer {
            Task { @MainActor in
                isRefreshing = false
            }
        }
        
        do {
            // Re-compute today's data if we're viewing today
            if selectedFrame == .day && Calendar.current.isDateInToday(currentDay) {
                try await computationService.computeStatsForDate(currentDay)
            }
            
            // Clear all caches to force reload
            segmentCache.removeAll()
            summaryCache.removeAll()
            usageCache.removeAll()
            yearlyCache = nil
            
            await loadYearlyData()
            await loadData()
        } catch {
            print("Error refreshing data: \(error)")
        }
    }
    
    private func loadYearlyData() async {
        // Return cached data if available
        if let cached = yearlyCache {
            await MainActor.run {
                yearlyKeySummaries = cached
            }
            return
        }
        
        // Get yearly data from stored daily stats only
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -365, to: endDate) ?? endDate
        
        let yearlyStatsDescriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate<DailyStats> { $0.date >= startDate && $0.date <= endDate },
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            let yearlyDailyStats = try context.fetch(yearlyStatsDescriptor)
            
            // Use stored daily stats to build yearly summaries (even if empty)
            let yearlySummaries = yearlyDailyStats.map { 
                KeyPressSummary(day: $0.date, count: $0.totalKeyPresses) 
            }
            
            // Cache the result
            yearlyCache = yearlySummaries
            
            await MainActor.run {
                yearlyKeySummaries = yearlySummaries
            }
        } catch {
            print("Error fetching yearly stored stats: \(error)")
            // Show empty data
            await MainActor.run {
                yearlyKeySummaries = []
            }
        }
    }

    private func startOfDay(on date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

// MARK: — GitHub Style Chart
struct GitHubStyleChart: View {
    let keySummaries: [KeyPressSummary]
    
    @State private var hoveredDate: Date?
    @State private var mouseLocation: CGPoint = .zero
    
    private let calendar = Calendar.current
    private let columns = 53 // ~1 year of weeks
    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 2
    
    private var yearData: [[Date?]] {
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -365, to: endDate) ?? endDate
        
        var weeks: [[Date?]] = Array(repeating: Array(repeating: nil, count: 7), count: columns)
        var currentDate = startDate
        
        // Find the starting week offset
        let weekday = calendar.component(.weekday, from: startDate)
        let startingWeekday = weekday == 1 ? 6 : weekday - 2 // Convert to Mon=0, Sun=6
        
        var week = 0
        var day = startingWeekday
        
        while currentDate <= endDate && week < columns {
            if day < 7 {
                weeks[week][day] = currentDate
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            day += 1
            
            if day >= 7 {
                day = 0
                week += 1
            }
        }
        
        return weeks
    }
    
    private func intensityForDate(_ date: Date) -> Double {
        let dayStart = calendar.startOfDay(for: date)
        let count = keySummaries.first { calendar.isDate($0.day, inSameDayAs: dayStart) }?.count ?? 0
        
        // Normalize to 0-1 scale based on max count
        let maxCount = keySummaries.map(\.count).max() ?? 1
        return Double(count) / Double(maxCount)
    }
    
    private func colorForIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.gray.opacity(0.1)
        } else if intensity < 0.25 {
            return Color.cyan.opacity(0.3)
        } else if intensity < 0.5 {
            return Color.cyan.opacity(0.5)
        } else if intensity < 0.75 {
            return Color.cyan.opacity(0.7)
        } else {
            return Color.cyan
        }
    }
    
    private func tooltipText(for date: Date) -> String {
        let dayStart = calendar.startOfDay(for: date)
        let count = keySummaries.first { calendar.isDate($0.day, inSameDayAs: dayStart) }?.count ?? 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let dateString = formatter.string(from: date)
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = " "
        let formattedCount = numberFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
        
        return "\(formattedCount) keys on \(dateString)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: cellSpacing) {
                ForEach(0..<columns, id: \.self) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(yearData[week][day] != nil ? 
                                      colorForIntensity(intensityForDate(yearData[week][day]!)) : 
                                      Color.clear)
                                .frame(width: cellSize, height: cellSize)
                                .onHover { isHovering in
                                    if isHovering, let date = yearData[week][day] {
                                        hoveredDate = date
                                    } else {
                                        hoveredDate = nil
                                    }
                                }
                        }
                    }
                }
            }
            
            HStack {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level == 0 ? Color.gray.opacity(0.1) : Color.cyan.opacity(0.2 + Double(level) * 0.2))
                            .frame(width: 10, height: 10)
                    }
                }
                
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .center) {
            if let hoveredDate = hoveredDate {
                Text(tooltipText(for: hoveredDate))
                    .font(.title)
                    .padding(6)
                    .background(Color.primary.colorInvert())
                    .foregroundColor(Color.primary)
                    .cornerRadius(4)
                    .shadow(radius: 4)
                    .offset(x: 0, y: -90)
            }
        }
    }
}

// MARK: — Cache Key
private struct TimeFrameKey: Hashable {
    let frame: TimeFrame
    let day: Date?
}


// MARK: — View
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel

    @State private var isDetailsSheetPresented = false
    
    init(context: ModelContext) {
        _viewModel = StateObject(
            wrappedValue: ContentViewModel(context: context)
        )
    }

    /// Minimum % to show both annotation and legend
    private let pctThreshold: Double = 2.0
    
    private var totalDuration: TimeInterval {
        viewModel.usageStats.reduce(0) { $0 + $1.duration }
    }

    private var totalDurationString: String {
        let h = Int(totalDuration) / 3600
        let m = (Int(totalDuration) % 3600) / 60
        let s = Int(totalDuration) % 60
        
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker(selection: $viewModel.selectedFrame, label: EmptyView()) {
                    ForEach(TimeFrame.allCases) { frame in
                        Text(frame.title).tag(frame)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 500)
                .onChange(of: viewModel.selectedFrame) { _, _ in
                    Task { await viewModel.loadData() }
                }
                
                if viewModel.selectedFrame == .day {
                    HStack {
                        Button(action: { viewModel.shiftCurrentDay(by: -1) }) {
                            Image(systemName: "chevron.left")
                        }
                        
                        Button("Today") {
                            viewModel.currentDay = Date()
                            Task { await viewModel.loadData() }
                        }
                        .fontWeight(Calendar.current.isDateInToday(viewModel.currentDay) ? .bold : .regular)
                        
                        Button(action: { viewModel.shiftCurrentDay(by: +1) }) {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(Calendar.current.isDateInToday(viewModel.currentDay))
                    }
                    
                    HStack(spacing: 4) {
                        Text(viewModel.currentDay.formatted(.dateTime.day()))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(viewModel.currentDay.formatted(.dateTime.month()))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(viewModel.currentDay.formatted(.dateTime.year()))
                            .font(.largeTitle)
                    }
                } else {
                    Text(viewModel.selectedFrame.displayLabel)
                        .font(.largeTitle)
                }
                
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                    .frame(width: 1100, height: 500)
                } else {
                    VStack(alignment: .center, spacing: 50) {
                        HStack(alignment: .top, spacing: 100) {
                            Chart {
                                ForEach(viewModel.usageStats) { item in
                                    SectorMark(
                                        angle: .value("Duration", item.duration),
                                        innerRadius: .ratio(0.4),
                                        outerRadius: .ratio(1.0)
                                    )
                                    .foregroundStyle(Color.uniqueColor(for: item.appName))
                                    .annotation(position: .overlay, alignment: .center) {
                                        let pct = item.duration / totalDuration * 100
                                        if pct >= pctThreshold {
                                            VStack(spacing: 2) {
                                                Text(Time.formatDuration(seconds: item.duration))
                                                    .font(.caption2)
                                                Text(String(format: "%.1f%%", pct))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                            .frame(width: 450, height: 450)
                            .chartLegend(.hidden)
                            .overlay {
                                VStack(spacing: 4) {
                                    Button {
                                        isDetailsSheetPresented = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                    }
                                    .help("View detailed app usage")
                                    Text(totalDurationString)
                                        .font(.title2)
                                        .bold()
                                }
                            }
                                
                            
                            Chart {
                                ForEach(Array(viewModel.segmentCounts.prefix(10))) { item in
                                    BarMark(
                                        x: .value("Keys", item.count),
                                        y: .value("App", item.appName)
                                    )
                                    .foregroundStyle(Color.uniqueColor(for: item.appName))
                                    .annotation(position: .trailing) {
                                        Text("\(item.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .chartXAxis(.hidden)
                            .frame(width: 500, height: 450)
                        }
                    }
                }
            }
            .frame(maxWidth: 1050) // Set maximum width to prevent overflow
            .padding(.horizontal, 40) // Add horizontal padding
            .padding(.vertical, 40) // Add vertical padding
            .frame(maxWidth: .infinity) // Center the content
            
            // GitHub chart section - completely outside all constraints
            HStack {
                Spacer()
                GitHubStyleChart(keySummaries: viewModel.yearlyKeySummaries)
                    .frame(height: 200)
                Spacer()
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    Task { await viewModel.refreshData() }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRefreshing)
                .help("Refresh and re-compute data")
            }
        }
        .sheet(isPresented: $isDetailsSheetPresented) {
            AppDetailsView(
                usageStats: viewModel.usageStats,
                totalDuration: totalDuration,
            )
        }
    }
}

