//
//  KeyLogger.swift
//  TrackMe
//
//  Created by Quang Huy on 07/05/2025.
//

import Cocoa
import SwiftData

final class KeyLogger: ObservableObject {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let modelContext: ModelContext

    init(context: ModelContext) {
        self.modelContext = context
        setUpEventTap()
    }
    
    deinit {
        tearDownEventTap()
    }

    private func setUpEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            let logger = Unmanaged<KeyLogger>.fromOpaque(refcon!).takeUnretainedValue()
            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                logger.logKeyEvent(keyCode: keyCode)
            }
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        guard let eventTap = eventTap else {
            print("⚠️ Couldn’t create event tap. Check Accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func tearDownEventTap() {
        if let eventTap = eventTap { CFMachPortInvalidate(eventTap) }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    private func logKeyEvent(keyCode: Int64) {
        let keyLog = KeyLog(keyCode: keyCode)
        modelContext.insert(keyLog)
        do {
            try modelContext.save()
            print("✅ Logged key: \(keyCode)")
        } catch {
            print("❌ Failed to save key log:", error)
        }
    }
}
