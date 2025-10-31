//
//  SharedConstants.swift
//  esp32Connect
//
//  Shared constants used across the app and extensions
//

import Foundation

/// Shared constants for app-wide configuration
struct SharedConstants {
    /// App Group identifier for sharing data between main app and extensions
    static let appGroupIdentifier = "group.com.barboursmith.pavloff"
    
    /// UserDefaults keys for shared data
    struct UserDefaultsKeys {
        static let hasAppSelection = "hasAppSelection"
        static let savedAppSelection = "savedAppSelection"
        static let lastWorkoutCompletion = "lastWorkoutCompletion"
    }
}
