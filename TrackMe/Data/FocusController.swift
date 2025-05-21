//
//  FocusController.swift
//  TrackMe
//
//  Created by Quang Huy on 08/05/2025.
//

import SwiftData
import Foundation

struct FocusController {
    static let shared = FocusController()

    let container: ModelContainer

    init() {
        let schema = Schema([Focus.self])
        let url = URL.applicationSupportDirectory.appending(path: "focus.store")
        let configuration = ModelConfiguration(schema: schema, url: url)
        container = try! ModelContainer(for: schema, configurations: [configuration])
    }
}
