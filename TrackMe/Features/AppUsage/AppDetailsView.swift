//
//  AppDetailsView.swift
//  TrackMe
//
//  Created by Quang Huy on 16/05/2025.
//

import SwiftUICore
import SwiftUI

struct AppDetailsView: View {
    let usageStats: [AppUsage]
    let totalDuration: TimeInterval
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(usageStats) { item in
                    let pct = (item.duration / totalDuration) * 100
                    
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.uniqueColor(for: item.appName))
                            .frame(width: 14, height: 14)
                        
                        Text(item.appName)
                            .font(.body)
                        
                        Spacer()
                        
                        Text(Time.formatDuration(seconds: item.duration))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "%.1f%%", pct))
                            .font(.callout)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("App Usage")
            .frame(height: 500)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

