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
    case failed(String)
    
    var displayText: String {
        switch self {
        case .pending: return "Pending..."
        case .connecting: return "Connecting..."
        case .discovering: return "Discovering..."
        case .connected: return "Connected"
        case .failed(let error): return "Failed: \(error)"
        }
    }
    
    static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending),
             (.connecting, .connecting),
             (.discovering, .discovering),
             (.connected, .connected):
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
