//
//  RootView.swift
//  TrackMe
//
//  Created by Quang Huy on 07/05/2025.
//

import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView(context: modelContext)
    }
}
