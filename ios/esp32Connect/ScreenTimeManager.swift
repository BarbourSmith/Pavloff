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
        
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else {
            print("[ScreenTime] No apps selected for blocking")
            return
        }
        
        // Shield the selected apps
        store.shield.applications = selectedApps.applicationTokens
        if !selectedApps.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selectedApps.categoryTokens)
        }
        
        print("[ScreenTime] App blocking enabled with \(selectedApps.applicationTokens.count) apps and \(selectedApps.categoryTokens.count) categories")
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
    }
}

