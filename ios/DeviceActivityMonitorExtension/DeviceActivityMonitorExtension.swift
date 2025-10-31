//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//
//  Monitor for device activity events to handle automatic app blocking at midnight
//

import DeviceActivity
import FamilyControls
import ManagedSettings

// The DeviceActivityMonitor is called by the system when schedule events occur
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    
    // Called when the schedule interval starts (at midnight for our daily schedule)
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        print("[DeviceActivityMonitor] Interval started for activity: \(activity)")
        
        // Check if this is our workout schedule
        if activity == DeviceActivityName("workoutSchedule") {
            handleMidnightReset()
        }
    }
    
    // Called when the schedule interval ends (at 11:59 PM for our daily schedule)
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        
        print("[DeviceActivityMonitor] Interval ended for activity: \(activity)")
    }
    
    // Handle the midnight reset - re-enable app blocking for the new day
    private func handleMidnightReset() {
        print("[DeviceActivityMonitor] Midnight reset triggered - checking if shields should be reapplied")
        
        // Use App Group UserDefaults
        guard let userDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) else {
            print("[DeviceActivityMonitor] Error: Failed to access App Group UserDefaults")
            return
        }
        
        // Check if workout was completed yesterday
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastCompletionDate = userDefaults.object(forKey: SharedConstants.UserDefaultsKeys.lastWorkoutCompletion) as? Date {
            let lastCompletionDay = calendar.startOfDay(for: lastCompletionDate)
            
            // If workout was completed yesterday, it's now a new day and shields should be reapplied
            if !calendar.isDate(lastCompletionDay, inSameDayAs: today) {
                print("[DeviceActivityMonitor] Workout not completed today yet - reapplying shields")
                reapplyShields(userDefaults: userDefaults)
            } else {
                print("[DeviceActivityMonitor] Workout already completed today - shields stay off")
            }
        } else {
            // No workout completion recorded, reapply shields
            print("[DeviceActivityMonitor] No workout completion found - reapplying shields")
            reapplyShields(userDefaults: userDefaults)
        }
    }
    
    // Reapply shields from the shared app group storage
    private func reapplyShields(userDefaults: UserDefaults) {
        // Check if we have apps selected
        guard userDefaults.bool(forKey: SharedConstants.UserDefaultsKeys.hasAppSelection) else {
            print("[DeviceActivityMonitor] No apps selected, skipping shield application")
            return
        }
        
        // Try to load the saved selection
        guard let data = userDefaults.data(forKey: SharedConstants.UserDefaultsKeys.savedAppSelection) else {
            print("[DeviceActivityMonitor] No saved selection data found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
            
            // Apply shields
            if !selection.applicationTokens.isEmpty {
                store.shield.applications = selection.applicationTokens
                print("[DeviceActivityMonitor] Reapplied shields for \(selection.applicationTokens.count) apps")
            }
            
            if !selection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selection.categoryTokens)
                print("[DeviceActivityMonitor] Reapplied shields for \(selection.categoryTokens.count) categories")
            }
            
        } catch {
            print("[DeviceActivityMonitor] Failed to decode selection: \(error)")
        }
    }
}
