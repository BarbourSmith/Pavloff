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
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    
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
        
        // Shield the selected apps
        store.shield.applications = selectedApps.applicationTokens
        store.shield.applicationCategories = selectedApps.categoryTokens
        
        // Set up the schedule from midnight to midnight next day (blocks until cleared)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        do {
            try activityCenter.startMonitoring(scheduleId, during: schedule)
            print("[ScreenTime] App blocking enabled from midnight")
        } catch {
            print("[ScreenTime] Failed to start monitoring: \(error)")
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
        
        // Stop monitoring
        activityCenter.stopMonitoring([scheduleId])
        
        print("[ScreenTime] App blocking disabled - workout completed!")
    }
    
    // Check if blocking is currently active
    var isBlockingEnabled: Bool {
        return store.shield.applications != nil || store.shield.applicationCategories != nil
    }
    
    // Clear all selected apps
    func clearSelection() {
        selectedApps = FamilyActivitySelection()
        disableAppBlocking()
    }
}
