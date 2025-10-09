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
        static let accelCharacteristic = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
        static let gyroCharacteristic = "beb5483e-36e1-4688-b7f5-ea07361b26a9"
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
