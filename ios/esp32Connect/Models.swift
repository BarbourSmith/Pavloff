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
    var x: Double
    var y: Double
    var z: Double
    var timestamp: Date
    
    init(x: Double = 0.0, y: Double = 0.0, z: Double = 0.0, timestamp: Date = Date()) {
        self.x = x
        self.y = y
        self.z = z
        self.timestamp = timestamp
    }
    
    var formattedX: String {
        String(format: "%.2f", x)
    }
    
    var formattedY: String {
        String(format: "%.2f", y)
    }
    
    var formattedZ: String {
        String(format: "%.2f", z)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Position Data Model
struct PositionData: Equatable {
    var x: Double
    var y: Double
    var z: Double
    
    init(x: Double = 0.0, y: Double = 0.0, z: Double = 0.0) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    var formattedX: String {
        String(format: "%.3f", x)
    }
    
    var formattedY: String {
        String(format: "%.3f", y)
    }
    
    var formattedZ: String {
        String(format: "%.3f", z)
    }
}

// MARK: - Device Data Container
struct DeviceData: Identifiable {
    let id: UUID
    let name: String
    var accelData: SensorData
    var gyroData: SensorData
    var positionData: PositionData
    var lastUpdate: Date
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
        self.accelData = SensorData()
        self.gyroData = SensorData()
        self.positionData = PositionData()
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
