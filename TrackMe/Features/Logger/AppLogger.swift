//
//  AppLogger.swift
//  TrackMe
//
//  Created by Quang Huy on 07/05/2025.
//

import Cocoa
import SwiftData
import ApplicationServices

extension Notification.Name {
    static let focusListDidChange = Notification.Name("focusListDidChange")
}

final class AppLogger: ObservableObject {
    private var appObserver: Any?
    
    private var chromeAXObserver: AXObserver?
    private var chromeAppElement: AXUIElement?
    
    private var vscodeAXObserver: AXObserver?
    private var vscodeAppElement: AXUIElement?
    
    private let autoLogContext: ModelContext
    private let focusContext: ModelContext

    @Published var lastLoggedAppName: String?
    @Published var lastLoggedTabName: String?
    
    @Published var focusOptions: [Focus] = []

    init(autoLogContext: ModelContext, focusContext: ModelContext) {
        self.autoLogContext = autoLogContext
        self.focusContext = focusContext
        
        setUpAppActivationObserver()
        setUpAppLifecycleObservers()
        
        setUpFocusListObserver()
        loadFocusOptions()
    }

    deinit {
        tearDownAppActivationObserver()
        removeChromeAXObserver()
        removeVSCodeAXObserver()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setUpFocusListObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFocusListChange),
            name: .focusListDidChange,
            object: nil
        )
    }

    @objc private func handleFocusListChange() {
        loadFocusOptions()
    }

    func loadFocusOptions() {
        do {
            let focuses = try focusContext.fetch(FetchDescriptor<Focus>())
            focusOptions = focuses
        } catch {
            print("❌ Failed to load focus options:", error)
        }
    }


    // MARK: - App Activation

    private func setUpAppActivationObserver() {
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            self?.handleAppActivation(note: note)
        }
    }

    private func tearDownAppActivationObserver() {
        if let obs = appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    private func handleAppActivation(note: Notification) {
        guard let activatedApp = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let appName = activatedApp.localizedName else {
            return
        }

        if appName == "Google Chrome" {
            installChromeAXObserver(for: activatedApp)
            removeVSCodeAXObserver()  // Remove VS Code observer if it was set
            let host = fetchChromeActiveTab()
            logChange(appName: appName, tabName: host)
        } else if appName == "Code" {
            installVSCodeAXObserver(for: activatedApp)
            removeChromeAXObserver()  // Remove Chrome observer if it was set
            let workingDir = fetchVSCodeWorkingDirectory()
            logChange(appName: appName, tabName: workingDir)
        } else {
            removeChromeAXObserver()
            removeVSCodeAXObserver()
            logChange(appName: appName, tabName: nil)
        }
    }

    // MARK: - Chrome Accessibility Observer

    private func setUpAppLifecycleObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.localizedName == "Google Chrome" {
                self?.removeChromeAXObserver()
            } else if app.localizedName == "Code" {
                self?.removeVSCodeAXObserver()
            }
        }
    }

    private func installChromeAXObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        chromeAppElement = AXUIElementCreateApplication(pid)
        var observer: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, context in
            let logger = Unmanaged<AppLogger>.fromOpaque(context!).takeUnretainedValue()
            logger.chromeTabDidChange()
        }

        // Create the AXObserver
        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success, let axObs = observer, let appElem = chromeAppElement else {
            print("❌ Failed to create AXObserver for Chrome: \(result)")
            return
        }

        chromeAXObserver = axObs

        AXObserverAddNotification(axObs, appElem,
                                      kAXFocusedWindowChangedNotification as CFString,
                                      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        AXObserverAddNotification(axObs, appElem,
                                  kAXTitleChangedNotification as CFString,
                                  UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

        // Add the observer to the run loop
        let runLoopSrc: CFRunLoopSource = AXObserverGetRunLoopSource(axObs)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSrc, .defaultMode)
    }

    private func removeChromeAXObserver() {
        if let axObs = chromeAXObserver, let appElem = chromeAppElement {
            AXObserverRemoveNotification(axObs, appElem, kAXFocusedWindowChangedNotification as CFString)
            AXObserverRemoveNotification(axObs, appElem, kAXTitleChangedNotification as CFString)
            chromeAXObserver = nil
            chromeAppElement = nil
        }
    }

    private func chromeTabDidChange() {
        // Use your existing AppleScript helper to fetch the URL (and normalize to host)
        if let host = fetchChromeActiveTab() {
            logChange(appName: "Google Chrome", tabName: host)
        } else {
            // If no URL came back, you might still want to log that Chrome is active
            logChange(appName: "Google Chrome", tabName: nil)
        }
    }
    
    // VS code
    private func installVSCodeAXObserver(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        vscodeAppElement = AXUIElementCreateApplication(pid)
        var observer: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, context in
            let logger = Unmanaged<AppLogger>.fromOpaque(context!).takeUnretainedValue()
            logger.vscodeWindowDidChange()
        }

        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success, let axObs = observer, let appElem = vscodeAppElement else {
            print("❌ Failed to create AXObserver for VS Code: \(result)")
            return
        }

        vscodeAXObserver = axObs

        AXObserverAddNotification(axObs, appElem,
                                  kAXFocusedWindowChangedNotification as CFString,
                                  UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))

        let runLoopSrc: CFRunLoopSource = AXObserverGetRunLoopSource(axObs)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSrc, .defaultMode)
    }
    
    private func removeVSCodeAXObserver() {
        if let axObs = vscodeAXObserver, let appElem = vscodeAppElement {
            AXObserverRemoveNotification(axObs, appElem, kAXFocusedWindowChangedNotification as CFString)
            vscodeAXObserver = nil
            vscodeAppElement = nil
        }
    }
    
    private func vscodeWindowDidChange() {
        let workingDir = fetchVSCodeWorkingDirectory()
        logChange(appName: "Code", tabName: workingDir)
    }
    

    // MARK: - Logging

    private func logChange(appName: String, tabName: String?) {
        // Avoid duplicate
        if appName == lastLoggedAppName && tabName == lastLoggedTabName {
            return
        }
        lastLoggedAppName = appName
        lastLoggedTabName = tabName

        let displayName = tabName.map({ "\(appName) - \($0)" }) ?? appName
        let entry = AppLog(timestamp: Date(), appName: displayName)
        autoLogContext.insert(entry)

        do {
            try autoLogContext.save()
            print("✅ Logged: \(displayName)")
        } catch {
            print("❌ Failed saving AppLog:", error)
        }
    }
    
    private func fetchChromeActiveTab() -> String? {
        // 1) AppleScript to get the URL of the frontmost Chrome tab
        let scriptSource = #"""
        tell application "Google Chrome"
            if not (exists window 1) then return ""
            tell front window to return URL of active tab
        end tell
        """#

        var error: NSDictionary?
        // Load the script
        guard let script = NSAppleScript(source: scriptSource) else {
            print("❌ Failed to initialize AppleScript")
            return nil
        }

        // Execute it (always gives you an NSAppleEventDescriptor)
        let descriptor = script.executeAndReturnError(&error)
        if let err = error {
            print("❌ AppleScript error fetching Chrome tab URL:", err)
            return nil
        }
        
        // Pull the URL string out of the descriptor
        guard
            let urlString = descriptor.stringValue,
            !urlString.isEmpty,
            let url = URL(string: urlString),
            let host = url.host
        else {
            return nil
        }

        // 2) Normalize host (remove "www.")
        let normalizedHost = host.lowercased()
            .replacingOccurrences(of: "www.", with: "")

        // 3) Check if host matches any focus options
        let matchingFocus = focusOptions.first { focus in
            focus.focusName.lowercased() == normalizedHost
        }

        return matchingFocus != nil ? normalizedHost : nil
    }
    
    private func fetchVSCodeWorkingDirectory() -> String? {
        let scriptSource = #"""
        tell application "System Events"
            delay 0.3
            tell process "Code"
                if exists window 1 then
                    return title of window 1
                else
                    return ""
                end if
            end tell
        end tell
        """#

        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            print("❌ Failed to initialize AppleScript for VS Code")
            return nil
        }

        let descriptor = script.executeAndReturnError(&error)
        if let err = error {
            print("❌ AppleScript error fetching VS Code window title:", err)
            return nil
        }

        guard let windowTitle = descriptor.stringValue,
              !windowTitle.isEmpty else {
            return nil
        }

        let cleanTitle = windowTitle.replacingOccurrences(of: "Visual Studio Code", with: "").replacingOccurrences(of: "Welcome", with: "")
        
        let parts = cleanTitle.components(separatedBy: " — ")
        
        if parts.count > 1 {
            let result = parts.last!.trimmingCharacters(in: .whitespaces)
            
            return result
        } else {
            return cleanTitle == "" ? nil : cleanTitle
        }
    }
}
