//
//  DeviceActivityMonitorExtension.swift
//  DeviceActivityMonitorExtension
//
//  Monitor for device activity events to handle automatic app blocking at midnight
//

import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings

// Shared constants to ensure consistency between app and extension
extension DeviceActivityName {
    static let workoutSchedule = Self("workoutSchedule")
}

extension DeviceActivityEvent.Name {
    static let midnightBlock = Self("midnightBlock")
}

// The DeviceActivityMonitor is called by the system when schedule events occur
public class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    let store = ManagedSettingsStore()
    
    // Date formatter for consistent logging
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public override init() {
        super.init()
        let timestamp = dateFormatter.string(from: Date())
        print("[DeviceActivityMonitor] \(timestamp): Extension initialized")
    }

    // Called when the schedule interval starts
    public override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        let timestamp = dateFormatter.string(from: Date())
        print("[DeviceActivityMonitor] \(timestamp): ⭐ Interval started for activity: \(activity)")
        print("[DeviceActivityMonitor] Expected activity name: \(DeviceActivityName.workoutSchedule)")
        print("[DeviceActivityMonitor] Activity names match: \(activity == .workoutSchedule)")

        if activity == .workoutSchedule {
            handleMidnightReset()
        } else {
            print("[DeviceActivityMonitor] ⚠️ Ignoring unknown activity: \(activity)")
        }
    }

    // Called when the schedule interval ends — also reapply shields as a safety net
    // in case intervalDidStart doesn't fire reliably on the next day
    public override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        let timestamp = dateFormatter.string(from: Date())
        print("[DeviceActivityMonitor] \(timestamp): ⭐ Interval ended for activity: \(activity)")

        if activity == .workoutSchedule {
            print("[DeviceActivityMonitor] Handling interval end as backup trigger")
            handleMidnightReset()
        } else {
            print("[DeviceActivityMonitor] ⚠️ Ignoring unknown activity: \(activity)")
        }
    }

    // Called when a threshold event is reached within the schedule
    public override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        let timestamp = dateFormatter.string(from: Date())
        print("[DeviceActivityMonitor] \(timestamp): ⭐ Event \(event) reached threshold for activity: \(activity)")
        print("[DeviceActivityMonitor] Expected event name: \(DeviceActivityEvent.Name.midnightBlock)")
        print("[DeviceActivityMonitor] Event names match: \(event == .midnightBlock)")

        if activity == .workoutSchedule && event == .midnightBlock {
            handleMidnightReset()
        } else {
            print("[DeviceActivityMonitor] ⚠️ Ignoring unknown activity/event combination")
        }
    }

    // Handle the midnight reset - re-enable app blocking for the new day
    private func handleMidnightReset() {
        let timestamp = dateFormatter.string(from: Date())
        print("[DeviceActivityMonitor] \(timestamp): Midnight reset triggered - checking if shields should be reapplied")
        
        // Use App Group UserDefaults
        guard let userDefaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") else {
            print("[DeviceActivityMonitor] ERROR: Failed to access App Group UserDefaults with suite 'group.com.maslowcnc.Tides'")
            return
        }
        
        print("[DeviceActivityMonitor] Successfully accessed App Group UserDefaults")

        // Test if UserDefaults has any data
        let hasAppSelectionFlag = userDefaults.bool(forKey: "hasAppSelection")
        let savedSelectionData = userDefaults.data(forKey: "savedAppSelection")
        let lastCompletionDate = userDefaults.object(forKey: "lastWorkoutCompletion") as? Date
        
        print("[DeviceActivityMonitor] UserDefaults state:")
        print("[DeviceActivityMonitor]   - hasAppSelection: \(hasAppSelectionFlag)")
        print("[DeviceActivityMonitor]   - savedAppSelection data size: \(savedSelectionData?.count ?? 0) bytes")
        print("[DeviceActivityMonitor]   - lastWorkoutCompletion: \(lastCompletionDate?.description ?? "nil")")

        // Check if workout was completed today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        print("[DeviceActivityMonitor] Today is: \(today)")

        if let lastCompletionDate = lastCompletionDate {
            let lastCompletionDay = calendar.startOfDay(for: lastCompletionDate)
            print("[DeviceActivityMonitor] Last completion day was: \(lastCompletionDay)")

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
        print("[DeviceActivityMonitor] reapplyShields() called")
        
        // Check if we have apps selected
        guard userDefaults.bool(forKey: "hasAppSelection") else {
            print("[DeviceActivityMonitor] No apps selected, skipping shield application")
            return
        }

        // Try to load the saved selection
        guard let data = userDefaults.data(forKey: "savedAppSelection") else {
            print("[DeviceActivityMonitor] No saved selection data found in UserDefaults")
            return
        }
        
        print("[DeviceActivityMonitor] Found selection data: \(data.count) bytes")

        do {
            let decoder = JSONDecoder()
            let selection = try decoder.decode(FamilyActivitySelection.self, from: data)
            
            print("[DeviceActivityMonitor] Successfully decoded selection:")
            print("[DeviceActivityMonitor]   - Application tokens: \(selection.applicationTokens.count)")
            print("[DeviceActivityMonitor]   - Category tokens: \(selection.categoryTokens.count)")
            print("[DeviceActivityMonitor]   - Web domain tokens: \(selection.webDomainTokens.count)")

            // Apply shields
            if !selection.applicationTokens.isEmpty {
                store.shield.applications = selection.applicationTokens
                print("[DeviceActivityMonitor] ✅ Reapplied shields for \(selection.applicationTokens.count) apps")
            }

            if !selection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selection.categoryTokens)
                print("[DeviceActivityMonitor] ✅ Reapplied shields for \(selection.categoryTokens.count) categories")
            }

            if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
                print("[DeviceActivityMonitor] ⚠️ Warning: Selection decoded but contains no tokens")
            }

        } catch {
            print("[DeviceActivityMonitor] ❌ Failed to decode selection: \(error)")
            print("[DeviceActivityMonitor] Error details: \(error.localizedDescription)")
        }
    }
}
