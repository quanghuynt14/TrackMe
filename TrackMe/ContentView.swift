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
    let minute: Date  // start of minute interval
    let count: Int    // number of key presses in that minute
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

    /// Count key presses per minute
    static func countKeyPressesPerMinute(keyLogs: [KeyLog]) -> [KeyPressSummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: keyLogs) { event in
            calendar.date(bySetting: .second, value: 0, of: event.timestamp)!  // round down to minute
        }
        return grouped.map { minute, events in
            KeyPressSummary(minute: minute, count: events.count)
        }
        .sorted(by: { $0.minute < $1.minute })
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
    @Published var isLoading: Bool = false

    private var segmentCache = [TimeFrameKey: [AppSegmentCount]]()
    private var summaryCache = [TimeFrameKey: [KeyPressSummary]]()
    private var usageCache   = [TimeFrameKey: [AppUsage]]()
    
    private var context: ModelContext

    init(context: ModelContext) {
        self.context = context
        Task { await loadData() }
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let frame = selectedFrame
        var fromDate: Date? = nil, toDate: Date? = nil
        if frame == .day {
            let start = startOfDay(on: currentDay)
            fromDate = start
            toDate = Calendar.current.date(byAdding: .day, value: 1, to: start)
        } else {
            fromDate = frame.startDate()
        }

        let key = TimeFrameKey(frame: frame, day: frame == .day ? fromDate : nil)
        if let cachedSegs = segmentCache[key],
           let cachedSumm = summaryCache[key],
           let usages = usageCache[key]{
            segmentCounts = cachedSegs
            keySummaries = cachedSumm
            usageStats = usages
            return
        }

        // build predicates
        let activePred: Predicate<AppLog>? = fromDate.map { from in
            toDate.map { to in
                #Predicate<AppLog> { $0.timestamp >= from && $0.timestamp < to }
            } ?? #Predicate<AppLog> { $0.timestamp >= from }
        }

        let keyPred: Predicate<KeyLog>? = fromDate.map { from in
            toDate.map { to in
                #Predicate<KeyLog> { $0.timestamp >= from && $0.timestamp < to }
            } ?? #Predicate<KeyLog> { $0.timestamp >= from }
        }

        // fetch logs
        let appLogs: [AppLog] = try! context.fetch(FetchDescriptor<AppLog>(predicate: activePred, sortBy: [SortDescriptor(\.timestamp)]))
        let keyLogs: [KeyLog] = try! context.fetch(FetchDescriptor<KeyLog>(predicate: keyPred, sortBy: [SortDescriptor(\.timestamp)]))

        // That’s exactly what you need to “carry over” the last app that was active before your time window begins.
        var extendedAppLogs = appLogs
        if let from = fromDate {
            // You’ll get back at most one object—the single latest log just before your from date.
            var prevFred = FetchDescriptor<AppLog>(
                predicate: #Predicate<AppLog> { $0.timestamp < from },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            prevFred.fetchLimit = 1
            
            if let prevLog = try? context.fetch(prevFred).first {
                // Make a “synthetic” AppLog at exactly fromDate
                let carryOver = AppLog(timestamp: from, appName: prevLog.appName)

                extendedAppLogs.insert(carryOver, at: 0)
            } else {
                let carryOver = AppLog(timestamp: from, appName: "Pre-Big Bang")

                extendedAppLogs.insert(carryOver, at: 0)
            }
        }
        
        // compute
        let segs = ChartDataService.countKeyPressesByApp(appLogs: extendedAppLogs, keyLogs: keyLogs)
        let summ = ChartDataService.countKeyPressesPerMinute(keyLogs: keyLogs)
        let usages = ChartDataService.usageTimeByApp(appLogs: extendedAppLogs)

        // cache them
        segmentCache[key] = segs
        summaryCache[key] = summ
        usageCache[key] = usages
        
        // publish
        segmentCounts = segs
        keySummaries = summ
        usageStats = usages
    }

    func shiftCurrentDay(by days: Int) {
        currentDay = Calendar.current.date(byAdding: .day, value: days, to: currentDay)!
        Task { await loadData() }
    }
    
    func refreshData() async {
        segmentCache.removeAll()
        summaryCache.removeAll()
        usageCache.removeAll()
        await loadData()
    }

    private func startOfDay(on date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
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
                    ProgressView().frame(height: 200)
                } else {
                    HStack(alignment: .top, spacing: 16) {
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
                                Text("Time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(totalDurationString)
                                    .font(.title2)
                                    .bold()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                isDetailsSheetPresented = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                            .help("View detailed app usage")
                            
                            ForEach(viewModel.usageStats) { item in
                                let pct = item.duration / totalDuration * 100
                                if pct >= pctThreshold {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.uniqueColor(for: item.appName))
                                            .frame(width: 12, height: 12)
                                        Text(item.appName)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    
                    Chart {
                        ForEach(Array(viewModel.segmentCounts.prefix(10))) { item in
                            BarMark(
                                x: .value("Keys", item.count),
                                y: .value("App", item.appName)
                            )
                            .annotation(position: .trailing) {
                                Text("\(item.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 300)
                    
                    Chart {
                        ForEach(viewModel.keySummaries) { summary in
                            BarMark(
                                x: .value("Time", summary.minute, unit: .minute),
                                y: .value("Count", summary.count)
                            )
                        }
                    }
                    .frame(height: 300)
                }
            }
            .padding()
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    Task { await viewModel.refreshData() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh data")
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

