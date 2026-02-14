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

    // Called when the schedule interval starts
    public override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        print("[DeviceActivityMonitor] Interval started for activity: \(activity)")

        if activity == .workoutSchedule {
            handleMidnightReset()
        }
    }

    // Called when the schedule interval ends — also reapply shields as a safety net
    // in case intervalDidStart doesn't fire reliably on the next day
    public override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        print("[DeviceActivityMonitor] Interval ended for activity: \(activity)")

        if activity == .workoutSchedule {
            handleMidnightReset()
        }
    }

    // Called when a threshold event is reached within the schedule
    public override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        print("[DeviceActivityMonitor] Event \(event) reached threshold for activity: \(activity)")

        if activity == .workoutSchedule && event == .midnightBlock {
            handleMidnightReset()
        }
    }

    // Handle the midnight reset - re-enable app blocking for the new day
    private func handleMidnightReset() {
        print("[DeviceActivityMonitor] Midnight reset triggered - checking if shields should be reapplied")

        // Use App Group UserDefaults
        guard let userDefaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") else {
            print("[DeviceActivityMonitor] Error: Failed to access App Group UserDefaults")
            return
        }

        // Check if workout was completed today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastCompletionDate = userDefaults.object(forKey: "lastWorkoutCompletion") as? Date {
            let lastCompletionDay = calendar.startOfDay(for: lastCompletionDate)

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
        guard userDefaults.bool(forKey: "hasAppSelection") else {
            print("[DeviceActivityMonitor] No apps selected, skipping shield application")
            return
        }

        // Try to load the saved selection
        guard let data = userDefaults.data(forKey: "savedAppSelection") else {
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

            if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
                print("[DeviceActivityMonitor] Warning: Selection decoded but contains no tokens")
            }

        } catch {
            print("[DeviceActivityMonitor] Failed to decode selection: \(error)")
        }
    }
}
