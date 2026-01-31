//
//  EventLog.swift
//  DeviceActivityMonitorExtension
//
//  Event logging system for debugging midnight app blocking and Screen Time events
//  This is a copy shared with the main app to enable logging from the extension
//

import Foundation

/// Represents a single logged event
struct LogEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let source: String
    let eventType: EventType
    let message: String
    
    init(source: String, eventType: EventType, message: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.source = source
        self.eventType = eventType
        self.message = message
    }
    
    enum EventType: String, Codable {
        case midnightTrigger = "Midnight Trigger"
        case workoutCompleted = "Workout Completed"
        case appsBlocked = "Apps Blocked"
        case appsUnblocked = "Apps Unblocked"
        case appLaunched = "App Launched"
        case extensionError = "Extension Error"
        case info = "Info"
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

/// Manages persisted event logs using App Group UserDefaults
class EventLogManager {
    static let shared = EventLogManager()
    
    private let maxLogEntries = 100
    private let logKey = "eventLogEntries"
    
    private let userDefaults: UserDefaults
    
    private init() {
        // Use App Group UserDefaults for sharing logs between app and extension
        if let defaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") {
            self.userDefaults = defaults
        } else {
            print("[EventLog] Warning: Failed to create App Group UserDefaults, falling back to standard")
            self.userDefaults = UserDefaults.standard
        }
    }
    
    /// Log an event
    func log(source: String, type: LogEvent.EventType, message: String) {
        let event = LogEvent(source: source, eventType: type, message: message)
        
        var events = getEvents()
        events.append(event)
        
        // Keep only the most recent entries
        if events.count > maxLogEntries {
            events = Array(events.suffix(maxLogEntries))
        }
        
        saveEvents(events)
        
        // Also print to console for debugging
        print("[\(source)] [\(type.rawValue)] \(message)")
    }
    
    /// Get all logged events
    func getEvents() -> [LogEvent] {
        guard let data = userDefaults.data(forKey: logKey) else {
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([LogEvent].self, from: data)
        } catch {
            print("[EventLog] Failed to decode events: \(error)")
            return []
        }
    }
    
    /// Save events to UserDefaults
    private func saveEvents(_ events: [LogEvent]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(events)
            userDefaults.set(data, forKey: logKey)
        } catch {
            print("[EventLog] Failed to encode events: \(error)")
        }
    }
    
    /// Clear all logged events
    func clearEvents() {
        userDefaults.removeObject(forKey: logKey)
        print("[EventLog] All events cleared")
    }
}
