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
            UserDefaults.standard.set(hasSelection, forKey: "hasAppSelection")
            
            // Persist the selection for app restarts
            saveSelection()
        }
    }
    
    private let store = ManagedSettingsStore()
    private let center = AuthorizationCenter.shared
    private let activityCenter = DeviceActivityCenter()
    
    private let scheduleId = DeviceActivityName("workoutSchedule")
    
    private init() {
        // Check initial authorization status
        Task {
            await checkAuthorizationStatus()
        }
        
        // Load persisted selection
        loadSelection()
    }
    
    // Save the selection to UserDefaults
    private func saveSelection() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(selectedApps)
            UserDefaults.standard.set(data, forKey: "savedAppSelection")
            print("[ScreenTime] Selection saved successfully")
        } catch {
            print("[ScreenTime] Failed to save selection: \(error)")
        }
    }
    
    // Load the selection from UserDefaults
    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: "savedAppSelection") else {
            print("[ScreenTime] No saved selection found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            selectedApps = try decoder.decode(FamilyActivitySelection.self, from: data)
            print("[ScreenTime] Selection loaded successfully with \(selectedApps.applicationTokens.count) apps")
        } catch {
            print("[ScreenTime] Failed to load selection: \(error)")
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
        
        // Only set shields if we have selection tokens in memory
        // After app restart, tokens are lost but shields persist in ManagedSettingsStore
        if !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty {
            // Set shields for selected apps
            store.shield.applications = selectedApps.applicationTokens
            if !selectedApps.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selectedApps.categoryTokens)
            }
            
            print("[ScreenTime] App blocking enabled with \(selectedApps.applicationTokens.count) apps and \(selectedApps.categoryTokens.count) categories")
        } else {
            // After app restart, we don't have tokens but shields persist automatically in ManagedSettingsStore
            // We can't reapply shields without tokens, but existing shields should still be active
            print("[ScreenTime] No tokens available to set shields (shields should persist from previous session)")
        }
    }
    
    // Disable app blocking when workout is completed
    func disableAppBlocking() {
        guard isAuthorized else {
            print("[ScreenTime] Not authorized to disable app blocking")
            return
        }
        
        // Remove shields
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
        return UserDefaults.standard.bool(forKey: "hasAppSelection")
    }
    
    // Clear all selected apps
    func clearSelection() {
        selectedApps = FamilyActivitySelection()
        disableAppBlocking()
        UserDefaults.standard.set(false, forKey: "hasAppSelection")
        UserDefaults.standard.removeObject(forKey: "savedAppSelection")
        print("[ScreenTime] Selection cleared")
    }
}

