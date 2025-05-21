//
//  Focus.swift
//  TrackMe
//
//  Created by Quang Huy on 08/05/2025.
//

import Foundation
import SwiftData

@Model
final class Focus {
    var focusName: String

    init(focusName: String) {
        self.focusName = focusName
    }
}
