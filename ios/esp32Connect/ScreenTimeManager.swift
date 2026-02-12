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

// Shared DeviceActivityName constant to ensure consistency between app and extension
extension DeviceActivityName {
    static let workoutSchedule = Self("workoutSchedule")
}

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
    
    private let scheduleId = DeviceActivityName.workoutSchedule
    
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
            return
        }
        
        // Check if we have apps selected (persisted flag)
        guard hasAppsSelected else {
            print("[ScreenTime] No apps have been selected for blocking")
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
            
            print("[ScreenTime] App blocking enabled with \(selectedApps.applicationTokens.count) apps and \(selectedApps.categoryTokens.count) categories")
        }
    }
    
    // Set up daily monitoring schedule to automatically re-enable blocking at midnight
    private func setupDailyMonitoring() {
        // Create a schedule that runs from midnight to 11:59 PM every day
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        do {
            // Start monitoring - this will trigger at the start of each interval (midnight)
            // When the interval starts, shields need to be reapplied
            try activityCenter.startMonitoring(scheduleId, during: schedule)
            print("[ScreenTime] Daily monitoring schedule established for midnight re-lock")
        } catch {
            print("[ScreenTime] Failed to start monitoring: \(error)")
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

