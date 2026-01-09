//
//  AppConfig.swift
//  esp32Connect
//
//  Configuration constants for the BLE IMU Data Monitor app
//

import Foundation

struct AppConfig {
    // BLE Configuration
    struct BLE {
        static let scanTimeout: TimeInterval = 10.0
        static let connectionTimeout: TimeInterval = 15.0
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 1.0
        static let monitoringDelay: TimeInterval = 0.25
    }
    
    // Device Configuration
    struct Devices {
        static let maxSelectableDevices = 2
        static let minSelectableDevices = 1
    }
    
    // Service and Characteristic UUIDs
    struct UUIDs {
        static let imuService = "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
        static let accelCharacteristic = "8d3f7a9e-4b2c-11ef-9f27-0242ac120002"  // Rep count characteristic
        static let gyroCharacteristic = "8d3f7a9e-4b2c-11ef-9f27-0242ac120002"  // Using same for compatibility
        static let durationCharacteristic = "7a8e6f9d-3c1b-42a8-9e7f-1234567890ab"  // Duration tracking characteristic
        static let sensitivityCharacteristic = "9c4a7f2e-5d3b-41a9-8f6e-2345678901bc"  // Sensitivity settings characteristic
    }
    
    // UI Configuration
    struct UI {
        struct Colors {
            static let primary = "#007BFF"
            static let success = "#28A745"
            static let error = "#F44336"
            static let warning = "#FF9800"
            static let background = "#F8F9FA"
            static let white = "#FFFFFF"
        }
        
        struct Timeouts {
            static let alertDismiss: TimeInterval = 5.0
            static let retryDelay: TimeInterval = 3.0
        }
    }
    
    // Error Messages
    struct Errors {
        static let bluetoothOff = "Bluetooth is turned off. Please enable Bluetooth and try again."
        static let noDevicesFound = "No devices found. Make sure your ESP32 devices are powered on and advertising."
        static let connectionFailed = "Failed to connect to device. Please try again."
        static let serviceNotFound = "IMU Service not found on this device."
        static let characteristicsNotFound = "Expected IMU characteristics not found."
        static let permissionDenied = "Bluetooth permissions are required for this app to work."
    }
}
