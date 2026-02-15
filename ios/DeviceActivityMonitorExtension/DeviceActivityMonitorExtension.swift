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
import os.log

// Shared constants to ensure consistency between app and extension
extension DeviceActivityName {
    static let workoutSchedule = Self("workoutSchedule")
}

extension DeviceActivityEvent.Name {
    static let midnightBlock = Self("midnightBlock")
}

// The DeviceActivityMonitor is called by the system when schedule events occur
public class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let logger = Logger(subsystem: "com.maslowcnc.Tides", category: "DeviceActivityMonitor")
    let store = ManagedSettingsStore()

    public override init() {
        super.init()
        logger.log("Extension initialized")
    }

    // Called when the schedule interval starts (midnight)
    public override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        logger.log("Interval started for activity: \(activity.rawValue, privacy: .public), matches workoutSchedule: \(activity == .workoutSchedule)")

        if activity == .workoutSchedule {
            handleMidnightReset()
        } else {
            logger.warning("Ignoring unknown activity: \(activity.rawValue, privacy: .public)")
        }
    }

    // Called when the schedule interval ends (23:00) — also reapply shields as a safety net
    // in case intervalDidStart doesn't fire reliably on the next day
    public override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        logger.log("Interval ended for activity: \(activity.rawValue, privacy: .public)")

        if activity == .workoutSchedule {
            logger.log("Handling interval end as backup trigger")
            handleMidnightReset()
        } else {
            logger.warning("Ignoring unknown activity: \(activity.rawValue, privacy: .public)")
        }
    }

    // Called when the schedule's warning time is reached (22:55)
    public override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)

        logger.log("Interval will end warning for activity: \(activity.rawValue, privacy: .public)")

        if activity == .workoutSchedule {
            handleMidnightReset()
        } else {
            logger.warning("Ignoring unknown activity: \(activity.rawValue, privacy: .public)")
        }
    }

    // Called when a threshold event is reached within the schedule
    public override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        logger.log("Event \(event.rawValue, privacy: .public) reached threshold for activity: \(activity.rawValue, privacy: .public), matches midnightBlock: \(event == .midnightBlock)")

        if activity == .workoutSchedule && event == .midnightBlock {
            handleMidnightReset()
        } else {
            logger.warning("Ignoring unknown activity/event combination")
        }
    }

    // Handle the midnight reset - re-enable app blocking for the new day
    private func handleMidnightReset() {
        logger.log("Midnight reset triggered - checking if shields should be reapplied")

        // Use App Group UserDefaults
        guard let userDefaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") else {
            logger.error("Failed to access App Group UserDefaults with suite 'group.com.maslowcnc.Tides'")
            return
        }

        logger.log("Successfully accessed App Group UserDefaults")

        // Log UserDefaults state for debugging
        let hasAppSelectionFlag = userDefaults.bool(forKey: "hasAppSelection")
        let savedSelectionData = userDefaults.data(forKey: "savedAppSelection")
        let lastCompletionDate = userDefaults.object(forKey: "lastWorkoutCompletion") as? Date

        logger.log("UserDefaults state: hasAppSelection=\(hasAppSelectionFlag), savedAppSelection=\(savedSelectionData?.count ?? 0) bytes, lastWorkoutCompletion=\(lastCompletionDate?.description ?? "nil", privacy: .public)")

        // Check if workout was completed today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        logger.log("Today is: \(today.description, privacy: .public)")

        if let lastCompletionDate = lastCompletionDate {
            let lastCompletionDay = calendar.startOfDay(for: lastCompletionDate)
            logger.log("Last completion day was: \(lastCompletionDay.description, privacy: .public)")

            if !calendar.isDate(lastCompletionDay, inSameDayAs: today) {
                logger.log("Workout not completed today yet - reapplying shields")
                reapplyShields(userDefaults: userDefaults)
            } else {
                logger.log("Workout already completed today - shields stay off")
            }
        } else {
            // No workout completion recorded, reapply shields
            logger.log("No workout completion found - reapplying shields")
            reapplyShields(userDefaults: userDefaults)
        }
    }

    // Reapply shields from the shared app group storage
    private func reapplyShields(userDefaults: UserDefaults) {
        logger.log("reapplyShields() called")

        // Check if we have apps selected
        guard userDefaults.bool(forKey: "hasAppSelection") else {
            logger.log("No apps selected, skipping shield application")
            return
        }

        // Try to load the saved selection
        guard let data = userDefaults.data(forKey: "savedAppSelection") else {
            logger.log("No saved selection data found in UserDefaults")
            return
        }

        logger.log("Found selection data: \(data.count) bytes")

        do {
            let decoder = JSONDecoder()
            let selection = try decoder.decode(FamilyActivitySelection.self, from: data)

            logger.log("Decoded selection: \(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories, \(selection.webDomainTokens.count) web domains")

            // Apply shields
            if !selection.applicationTokens.isEmpty {
                store.shield.applications = selection.applicationTokens
                logger.log("Reapplied shields for \(selection.applicationTokens.count) apps")
            }

            if !selection.categoryTokens.isEmpty {
                store.shield.applicationCategories = .specific(selection.categoryTokens)
                logger.log("Reapplied shields for \(selection.categoryTokens.count) categories")
            }

            if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
                logger.warning("Selection decoded but contains no tokens")
            }

        } catch {
            logger.error("Failed to decode selection: \(error.localizedDescription, privacy: .public)")
        }
    }
}
