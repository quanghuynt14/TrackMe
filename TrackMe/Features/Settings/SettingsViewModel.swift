//
//  SettingsViewModel.swift
//  TrackMe
//
//  Created by Quang Huy on 08/05/2025.
//

import Foundation
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var focusOptions: [Focus] = []
    @Published var newFocusName: String = ""

    private var context: ModelContext

    init(context: ModelContext) {
        self.context = context
        Task { await loadFocusOptions() }
    }

    func loadFocusOptions() async {
        do {
            let focuses = try context.fetch(FetchDescriptor<Focus>())
            focusOptions = focuses
        } catch {
            print("❌ Failed to load focus options:", error)
        }
    }

    func addFocus() {
        guard !newFocusName.isEmpty else { return }
        let newFocus = Focus(focusName: newFocusName)
        context.insert(newFocus)
        Task { await loadFocusOptions() }
        newFocusName = ""
        NotificationCenter.default.post(name: .focusListDidChange, object: nil)
    }

    func deleteFocus(at offsets: IndexSet) {
        for index in offsets {
            let focus = focusOptions[index]
            context.delete(focus)
        }
        Task { await loadFocusOptions() }
        NotificationCenter.default.post(name: .focusListDidChange, object: nil)
    }
}
