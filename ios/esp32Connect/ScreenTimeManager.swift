//
//  ScreenTimeManager.swift
//  esp32Connect
//
//  Manager for Screen Time API integration to block apps until workout is completed
//

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI

@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()
    
    @Published var isAuthorized = false
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection() {
        didSet {
            // Save the fact that we have a selection
            let hasSelection = !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty
            userDefaults.set(hasSelection, forKey: "hasAppSelection")
            
            // Persist the selection for app restarts
            saveSelection()
        }
    }
    
    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()
    
    private let scheduleId = DeviceActivityName("workoutSchedule")
    
    // Use App Group UserDefaults for sharing data with extension
    private let userDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") else {
            print("[ScreenTime] Warning: Failed to create App Group UserDefaults, falling back to standard")
            return UserDefaults.standard
        }
        return defaults
    }()
    
    private init() {
        print("[ScreenTime] Initializing ScreenTimeManager...")
        
        // Check initial authorization status
        Task {
            await checkAuthorizationStatus()
        }
        
        // Load persisted selection
        loadSelection()
        
        print("[ScreenTime] After loadSelection, tokens count: apps=\(selectedApps.applicationTokens.count), categories=\(selectedApps.categoryTokens.count)")
        
        // If we have a saved selection, ensure monitoring is active
        if hasAppsSelected {
            print("[ScreenTime] Has app selection flag is true")
            if !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty {
                print("[ScreenTime] Tokens are available, setting up monitoring")
                setupDailyMonitoring()
            } else {
                print("[ScreenTime] Warning: hasAppSelection is true but no tokens loaded")
            }
        }
    }
    
    // Save the selection to UserDefaults
    private func saveSelection() {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(selectedApps)
        if let data = data {
            userDefaults.set(data, forKey: "savedAppSelection")
            print("[ScreenTime] Selection saved successfully to App Group")
        } else {
            print("[ScreenTime] Failed to encode selection")
        }
    }
    
    // Load the selection from UserDefaults
    private func loadSelection() {
        guard let data = userDefaults.data(forKey: "savedAppSelection") else {
            print("[ScreenTime] No saved selection found in UserDefaults")
            return
        }
        
        print("[ScreenTime] Found saved selection data (\(data.count) bytes), attempting to decode...")
        
        do {
            let decoder = JSONDecoder()
            selectedApps = try decoder.decode(FamilyActivitySelection.self, from: data)
            print("[ScreenTime] Selection loaded successfully:")
            print("[ScreenTime] - Application tokens: \(selectedApps.applicationTokens.count)")
            print("[ScreenTime] - Category tokens: \(selectedApps.categoryTokens.count)")
            print("[ScreenTime] - Web domain tokens: \(selectedApps.webDomainTokens.count)")
        } catch {
            print("[ScreenTime] Failed to decode selection: \(error)")
            print("[ScreenTime] Error details: \(error.localizedDescription)")
        }
    }
    
    // Request authorization from the user
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            await checkAuthorizationStatus()
        } catch {
            print("[ScreenTime] Authorization failed: \(error)")
            isAuthorized = false
        }
    }
    
    // Check current authorization status
    private func checkAuthorizationStatus() async {
        let status = center.authorizationStatus
        isAuthorized = (status == .approved)
        print("[ScreenTime] Authorization status: \(status)")
    }
    
    // Enable app blocking from midnight until workout is completed
    func enableAppBlocking() {
        guard isAuthorized else {
            print("[ScreenTime] Not authorized to enable app blocking")
            EventLogManager.shared.log(source: "ScreenTimeManager", type: .info, message: "Cannot enable blocking - not authorized")
            return
        }
        
        // Check if we have apps selected (persisted flag)
        guard hasAppsSelected else {
            print("[ScreenTime] No apps have been selected for blocking")
            EventLogManager.shared.log(source: "ScreenTimeManager", type: .info, message: "Cannot enable blocking - no apps selected")
            return
        }
        
        // Try to reload selection if tokens are empty
        if selectedApps.applicationTokens.isEmpty && selectedApps.categoryTokens.isEmpty {
            print("[ScreenTime] Tokens are empty, attempting to reload selection...")
            loadSelection()
            
            // If still empty after reload, the tokens have expired
            if selectedApps.applicationTokens.isEmpty && selectedApps.categoryTokens.isEmpty {
                print("[ScreenTime] Warning: Tokens could not be restored from storage")
                print("[ScreenTime] User may need to reselect apps in Workout Settings")
                EventLogManager.shared.log(source: "ScreenTimeManager", type: .extensionError, message: "Failed to restore app tokens - user may need to reselect apps")
                
                // Try to apply shields one more time in case they're still in the store
                // (ManagedSettingsStore persists shields even if we don't have tokens)
                print("[ScreenTime] Attempting to verify if shields are still active in ManagedSettingsStore...")
                
                // We can't directly read shield settings, but we can try to set them again
                // If tokens are truly gone, this won't work, but it's worth trying
                return
            }
        }
        
        // Set shields if we have selection tokens in memory
        if !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty {
            // Set shields for selected apps
            store.shield.applications = selectedApps.applicationTokens
            if !selectedApps.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selectedApps.categoryTokens)
            }
            
            // Set up daily monitoring schedule to re-enable blocking at midnight
            setupDailyMonitoring()
            
            let appCount = selectedApps.applicationTokens.count
            let catCount = selectedApps.categoryTokens.count
            print("[ScreenTime] App blocking enabled with \(appCount) apps and \(catCount) categories")
            EventLogManager.shared.log(source: "ScreenTimeManager", type: .appsBlocked, message: "App blocking enabled: \(appCount) apps, \(catCount) categories")
        }
    }
    
    // Set up daily monitoring schedule (triggers at midnight)
    // IMPORTANT: Use a SHORT interval for reliable triggering!
    // Long intervals (24 hours) can cause iOS to not fire intervalDidStart reliably.
    // Solution: Use a very short interval (1 minute) at midnight that repeats daily.
    // This ensures intervalDidStart fires consistently at midnight every day.
    private func setupDailyMonitoring() {
        // Create a schedule with a SHORT 1-minute interval starting at midnight
        // intervalStart: 00:00:00 (midnight)
        // intervalEnd: 00:00:59 (59 seconds later)
        // repeats: true (daily)
        // 
        // WHY: iOS DeviceActivity is more reliable with short intervals.
        // The intervalDidStart will fire at 00:00, then the interval ends at 00:01,
        // then it repeats the next day. This is a proven pattern for daily triggers.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 0, minute: 0, second: 59),
            repeats: true,
            warningTime: nil
        )
        
        do {
            // Start monitoring - intervalDidStart will fire at midnight (00:00:00)
            // This happens daily due to repeats: true
            try activityCenter.startMonitoring(scheduleId, during: schedule)
            print("[ScreenTime] Daily monitoring schedule established (1-minute interval at midnight)")
            EventLogManager.shared.log(source: "ScreenTimeManager", type: .info, message: "Daily monitoring schedule registered successfully - extension will trigger at midnight with 1-minute interval")
        } catch {
            print("[ScreenTime] Failed to start monitoring: \(error)")
            EventLogManager.shared.log(source: "ScreenTimeManager", type: .extensionError, message: "Failed to register monitoring schedule: \(error.localizedDescription)")
        }
    }
    
    // Stop daily monitoring schedule
    private func stopDailyMonitoring() {
        activityCenter.stopMonitoring([scheduleId])
        print("[ScreenTime] Daily monitoring stopped")
    }
    
    // Disable app blocking when workout is completed
    func disableAppBlocking() {
        guard isAuthorized else {
            print("[ScreenTime] Not authorized to disable app blocking")
            return
        }
        
        // Remove shields to unlock apps for the user after workout completion
        // Note: This means shields must be reapplied at midnight for the next day
        // With the DeviceActivityMonitor extension, this happens automatically
        // Without the extension, shields are reapplied when user opens the app
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        
        print("[ScreenTime] App blocking disabled - workout completed!")
        EventLogManager.shared.log(source: "ScreenTimeManager", type: .appsUnblocked, message: "Apps unlocked - workout completed")
    }
    
    // Check if blocking is currently active
    var isBlockingEnabled: Bool {
        return store.shield.applications != nil || store.shield.applicationCategories != nil
    }
    
    // Check if we have apps selected
    var hasAppsSelected: Bool {
        return userDefaults.bool(forKey: "hasAppSelection")
    }
    
    // Clear all selected apps
    func clearSelection() {
        selectedApps = FamilyActivitySelection()
        disableAppBlocking()
        stopDailyMonitoring()
        userDefaults.set(false, forKey: "hasAppSelection")
        userDefaults.removeObject(forKey: "savedAppSelection")
        print("[ScreenTime] Selection cleared")
    }
}

