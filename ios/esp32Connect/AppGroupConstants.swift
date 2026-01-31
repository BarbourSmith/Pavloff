//
//  AppGroupConstants.swift
//  esp32Connect
//
//  Shared constants for App Group identifiers and UserDefaults keys
//

import Foundation

/// Constants shared between the main app and extension
enum AppGroupConstants {
    /// App Group identifier for sharing data between app and extension
    static let appGroupIdentifier = "group.com.maslowcnc.Tides"
    
    /// UserDefaults keys for shared data
    enum Keys {
        static let hasAppSelection = "hasAppSelection"
        static let savedAppSelection = "savedAppSelection"
        static let lastWorkoutCompletion = "lastWorkoutCompletion"
        static let eventLogEntries = "eventLogEntries"
        static let lastWorkoutActivity = "lastWorkoutActivity"
        static let currentExerciseIndex = "currentExerciseIndex"
    }
}
