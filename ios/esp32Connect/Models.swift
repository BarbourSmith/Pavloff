//
//  Models.swift
//  esp32Connect
//
//  Data models for the BLE IMU Data Monitor app
//

import Foundation
import CoreBluetooth

// MARK: - BLE Device Model
struct BLEDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
    var rssi: Int
    
    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Device Connection Status
enum ConnectionStatus: Equatable {
    case pending
    case connecting
    case discovering
    case connected
    case disconnected
    case failed(String)
    
    var displayText: String {
        switch self {
        case .pending: return "Pending..."
        case .connecting: return "Connecting..."
        case .discovering: return "Discovering..."
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .failed(let error): return "Failed: \(error)"
        }
    }
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending),
             (.connecting, .connecting),
             (.discovering, .discovering),
             (.connected, .connected),
             (.disconnected, .disconnected):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Sensor Data Model
struct SensorData: Equatable {
    var count: Int
    var state: String
    var timestamp: Date
    
    init(count: Int = 0, state: String = "IDLE", timestamp: Date = Date()) {
        self.count = count
        self.state = state
        self.timestamp = timestamp
    }
    
    var formattedCount: String {
        String(count)
    }
    
    var formattedState: String {
        state.uppercased()
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
    
    var stateColor: String {
        switch state.uppercased() {
        case "UP":
            return "green"
        case "DOWN":
            return "blue"
        case "IDLE":
            return "gray"
        default:
            return "orange"
        }
    }
}

// MARK: - Device Data Container
struct DeviceData: Identifiable {
    let id: UUID
    let name: String
    var accelData: SensorData
    var gyroData: SensorData
    var lastUpdate: Date
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
        self.accelData = SensorData()
        self.gyroData = SensorData()
        self.lastUpdate = Date()
    }
}

// MARK: - Discovered Characteristics
struct DiscoveredCharacteristics {
    var accelUUID: CBUUID?
    var gyroUUID: CBUUID?
    
    var isComplete: Bool {
        return accelUUID != nil && gyroUUID != nil
    }
}

// MARK: - Workout Models
struct Exercise: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    var targetReps: Int
    
    init(id: UUID = UUID(), name: String, targetReps: Int) {
        self.id = id
        self.name = name
        self.targetReps = targetReps
    }
}

struct WorkoutSettings: Codable {
    var exercises: [Exercise]
    
    private static let userDefaultsKey = "workoutSettings"
    
    static let defaultExercises = [
        Exercise(name: "Bicep Curls", targetReps: 10),
        Exercise(name: "Shoulder Press", targetReps: 10),
        Exercise(name: "Lateral Raises", targetReps: 10)
    ]
    
    init(exercises: [Exercise] = defaultExercises) {
        self.exercises = exercises
    }
    
    // Load saved settings from UserDefaults, or return default if none saved
    static func load() -> WorkoutSettings {
        // Use App Group UserDefaults for consistency with other workout data
        let userDefaults: UserDefaults = {
            guard let defaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") else {
                print("[WORKOUT_SETTINGS] Warning: Failed to create App Group UserDefaults, falling back to standard")
                return UserDefaults.standard
            }
            return defaults
        }()
        
        guard let data = userDefaults.data(forKey: userDefaultsKey) else {
            print("[WORKOUT_SETTINGS] No saved settings found, using defaults")
            return WorkoutSettings()
        }
        
        do {
            let settings = try JSONDecoder().decode(WorkoutSettings.self, from: data)
            print("[WORKOUT_SETTINGS] Successfully loaded saved settings with \(settings.exercises.count) exercises")
            return settings
        } catch {
            print("[WORKOUT_SETTINGS] Failed to decode saved settings: \(error). Using defaults.")
            return WorkoutSettings()
        }
    }
    
    // Save current settings to UserDefaults
    func save() {
        // Use App Group UserDefaults for consistency with other workout data
        let userDefaults: UserDefaults = {
            guard let defaults = UserDefaults(suiteName: "group.com.maslowcnc.Tides") else {
                print("[WORKOUT_SETTINGS] Warning: Failed to create App Group UserDefaults, falling back to standard")
                return UserDefaults.standard
            }
            return defaults
        }()
        
        do {
            let data = try JSONEncoder().encode(self)
            userDefaults.set(data, forKey: WorkoutSettings.userDefaultsKey)
            print("[WORKOUT_SETTINGS] Successfully saved settings")
        } catch {
            print("[WORKOUT_SETTINGS] Failed to encode settings: \(error)")
        }
    }
}

// MARK: - Streak Tracking
class StreakManager: ObservableObject {
    static let shared = StreakManager()
    
    @Published private(set) var currentStreak: Int = 0
    
    private let currentStreakKey = "currentWorkoutStreak"
    private let lastWorkoutDateKey = "lastWorkoutDate"
    
    private init() {
        loadStreakData()
    }
    
    private func loadStreakData() {
        currentStreak = UserDefaults.standard.integer(forKey: currentStreakKey)
    }
    
    func checkAndUpdateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get last workout date
        if let lastWorkoutDate = UserDefaults.standard.object(forKey: lastWorkoutDateKey) as? Date {
            let lastWorkoutDay = calendar.startOfDay(for: lastWorkoutDate)
            
            // Check if workout was already done today
            if calendar.isDate(lastWorkoutDay, inSameDayAs: today) {
                print("[STREAK] Workout already completed today, streak unchanged: \(currentStreak)")
                return
            }
            
            // Check if yesterday (consecutive day)
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               calendar.isDate(lastWorkoutDay, inSameDayAs: yesterday) {
                // Consecutive day - increment streak
                currentStreak += 1
                print("[STREAK] Consecutive day! Streak increased to: \(currentStreak)")
            } else {
                // Missed day(s) - reset streak
                print("[STREAK] Missed day(s), streak reset from \(currentStreak) to 1")
                currentStreak = 1
            }
        } else {
            // First workout ever
            currentStreak = 1
            print("[STREAK] First workout! Streak started at: 1")
        }
        
        // Save current streak and today's date
        UserDefaults.standard.set(currentStreak, forKey: currentStreakKey)
        UserDefaults.standard.set(today, forKey: lastWorkoutDateKey)
    }
    
    func isMilestone(_ streak: Int) -> Bool {
        return [7, 30, 50, 100, 365].contains(streak)
    }
    
    func getMilestoneMessage(_ streak: Int) -> String? {
        switch streak {
        case 7:
            return "🎉 7 Day Streak! One week strong!"
        case 30:
            return "🔥 30 Day Streak! A full month!"
        case 50:
            return "💪 50 Day Streak! Incredible!"
        case 100:
            return "🏆 100 Day Streak! You're unstoppable!"
        case 365:
            return "👑 365 Day Streak! A full year! Legendary!"
        default:
            return nil
        }
    }
}
