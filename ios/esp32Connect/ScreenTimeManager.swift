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
import os.log

// Shared constants to ensure consistency between app and extension
extension DeviceActivityName {
    static let workoutSchedule = Self("workoutSchedule")
}


@MainActor
class ScreenTimeManager: ObservableObject {
    static let shared = ScreenTimeManager()

    private let logger = Logger(subsystem: "com.maslowcnc.Tides", category: "ScreenTimeManager")

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
            return UserDefaults.standard
        }
        return defaults
    }()

    private init() {
        logger.log("Initializing ScreenTimeManager...")

        // Check initial authorization status
        Task {
            await checkAuthorizationStatus()
        }

        // Load persisted selection
        loadSelection()

        logger.log("After loadSelection, tokens count: apps=\(self.selectedApps.applicationTokens.count), categories=\(self.selectedApps.categoryTokens.count)")

        // If we have a saved selection, ensure monitoring is active and shields are applied
        if hasAppsSelected {
            logger.log("Has app selection flag is true")
            if !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty {
                logger.log("Tokens are available, checking monitoring state")

                // Only start monitoring if it isn't already running. Every call to
                // setupDailyMonitoring() issues stopMonitoring + startMonitoring.
                // Doing that mid-interval (e.g. whenever the user opens the app during
                // the day) disrupts iOS Screen Time's internal accounting and causes
                // "time's up" banners to appear even with zero actual app usage.
                // The same guard exists in enableAppBlocking() for the same reason.
                if !activityCenter.activities.contains(scheduleId) {
                    logger.log("Monitoring not active — starting daily monitoring")
                    setupDailyMonitoring()
                } else {
                    logger.log("Monitoring already active — skipping setupDailyMonitoring()")
                }

                // Proactively apply shields on init if workout not completed today.
                // This is critical because the DeviceActivityMonitor extension callbacks
                // (intervalDidStart, intervalDidEnd) are unreliable and may not fire.
                // By applying shields here, we ensure blocking is active whenever the app
                // process starts (app launch, foreground, or system restart).
                if !isWorkoutCompletedToday() {
                    logger.log("Workout not completed today — applying shields proactively on init")
                    store.shield.applications = selectedApps.applicationTokens
                    if !selectedApps.categoryTokens.isEmpty {
                        store.shield.applicationCategories = .specific(selectedApps.categoryTokens)
                    }
                } else {
                    logger.log("Workout already completed today — leaving shields off")
                }
            } else {
                logger.warning("hasAppSelection is true but no tokens loaded")
            }
        }
    }

    // Check if workout was completed today (shared logic for init and extension)
    private func isWorkoutCompletedToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastCompletionDate = userDefaults.object(forKey: "lastWorkoutCompletion") as? Date {
            let lastCompletionDay = calendar.startOfDay(for: lastCompletionDate)
            return calendar.isDate(lastCompletionDay, inSameDayAs: today)
        }
        return false
    }

    // Save the selection to UserDefaults
    private func saveSelection() {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(selectedApps)
        if let data = data {
            userDefaults.set(data, forKey: "savedAppSelection")
            logger.log("Selection saved successfully to App Group")
        } else {
            logger.error("Failed to encode selection")
        }
    }

    // Load the selection from UserDefaults
    private func loadSelection() {
        guard let data = userDefaults.data(forKey: "savedAppSelection") else {
            logger.log("No saved selection found in UserDefaults")
            return
        }

        logger.log("Found saved selection data (\(data.count) bytes), attempting to decode...")

        do {
            let decoder = JSONDecoder()
            selectedApps = try decoder.decode(FamilyActivitySelection.self, from: data)
            logger.log("Selection loaded: \(self.selectedApps.applicationTokens.count) apps, \(self.selectedApps.categoryTokens.count) categories, \(self.selectedApps.webDomainTokens.count) web domains")
        } catch {
            logger.error("Failed to decode selection: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Request authorization from the user
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            await checkAuthorizationStatus()
        } catch {
            logger.error("Authorization failed: \(error.localizedDescription, privacy: .public)")
            isAuthorized = false
        }
    }

    // Check current authorization status
    private func checkAuthorizationStatus() async {
        let status = center.authorizationStatus
        isAuthorized = (status == .approved)
        logger.log("Authorization status: \(String(describing: status), privacy: .public)")
    }

    // Enable app blocking from midnight until workout is completed
    func enableAppBlocking() {
        guard isAuthorized else {
            logger.log("Not authorized to enable app blocking")
            return
        }

        // Check if we have apps selected (persisted flag)
        guard hasAppsSelected else {
            logger.log("No apps have been selected for blocking")
            return
        }

        // Try to reload selection if tokens are empty
        if selectedApps.applicationTokens.isEmpty && selectedApps.categoryTokens.isEmpty {
            logger.log("Tokens are empty, attempting to reload selection...")
            loadSelection()

            // If still empty after reload, the tokens have expired
            if selectedApps.applicationTokens.isEmpty && selectedApps.categoryTokens.isEmpty {
                logger.warning("Tokens could not be restored from storage — user may need to reselect apps")
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

            // Only start monitoring if it isn't already running. Calling
            // stopMonitoring + startMonitoring mid-interval (e.g. on every
            // foreground event) disrupts iOS Screen Time's internal accounting
            // and causes "time's up" banners to appear on apps that have
            // built-in App Limits, even with zero actual usage. The monitoring
            // schedule handles its own daily reset via intervalDidStart.
            if !activityCenter.activities.contains(scheduleId) {
                setupDailyMonitoring()
            }

            logger.log("App blocking enabled with \(self.selectedApps.applicationTokens.count) apps and \(self.selectedApps.categoryTokens.count) categories")
        }
    }

    // Set up daily monitoring schedule to automatically re-enable blocking at midnight
    private func setupDailyMonitoring() {
        // Schedule from 00:00 to 23:00 with a 1-hour gap before the next day.
        // This ensures the system recognizes a distinct interval boundary each day
        // and reliably fires intervalDidStart at midnight.
        //
        // warningTime fires intervalWillEndWarning 5 minutes before intervalEnd (at 22:55),
        // giving us a 4th callback opportunity to reapply shields.
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 0),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        do {
            // Stop any existing monitoring first to ensure clean state
            activityCenter.stopMonitoring([scheduleId])
            logger.log("Stopped existing monitoring")

            // Start monitoring with interval callbacks only (no threshold events).
            // DeviceActivityEvent thresholds share iOS Screen Time's usage-limit
            // accounting layer; registering a 1-minute threshold for an app that
            // the user also has a built-in App Limit on causes the "time's up"
            // banner to appear after just 1 minute of use, even after Pavloff
            // removes its own ManagedSettings shield. Interval callbacks
            // (intervalDidStart, intervalDidEnd, intervalWillEndWarning) are
            // sufficient — proactive shield application in the main app covers
            // any gap at midnight.
            try activityCenter.startMonitoring(
                scheduleId,
                during: schedule
            )
            logger.log("Daily monitoring schedule established (00:00-23:00, warningTime=5min, repeats=true)")
        } catch {
            logger.error("Failed to start monitoring: \(error.localizedDescription, privacy: .public)")
        }
    }

    // Stop daily monitoring schedule
    private func stopDailyMonitoring() {
        activityCenter.stopMonitoring([scheduleId])
        logger.log("Daily monitoring stopped")
    }

    // Disable app blocking when workout is completed
    func disableAppBlocking() {
        // NOTE: Do NOT guard on isAuthorized here. isAuthorized is an in-memory cache
        // set by an async task in init(), so it can be stale/false even when the
        // FamilyControls framework is fully authorized (e.g. granted in a prior session).
        // Shields are applied in init() without this check for the same reason.
        // Clearing shields is always safe and should never be blocked by a stale flag.

        // Clear the shared ManagedSettingsStore. Per Apple WWDC 2021 "Meet the
        // Screen Time API", the default ManagedSettingsStore() is shared across
        // all processes in the same app group — so clearing it here also clears
        // any shields the DeviceActivityMonitor extension applied.
        //
        // Do NOT call setupDailyMonitoring() here. Stopping and restarting
        // monitoring mid-interval (after each workout) disrupts iOS Screen Time's
        // internal accounting and causes "time's up" banners to appear on apps
        // that have built-in App Limits, even when those apps have 0 actual usage.
        // The already-running monitoring schedule will fire intervalDidStart at
        // midnight to re-enable blocking for the next day.
        store.shield.applications = nil
        store.shield.applicationCategories = nil

        logger.log("App blocking disabled — workout completed!")
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
        logger.log("Selection cleared")
    }
}
