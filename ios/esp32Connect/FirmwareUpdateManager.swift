//
//  FirmwareUpdateManager.swift
//  esp32Connect
//
//  Manages OTA firmware updates: sends BLE command to trigger AP mode,
//  then guides user to connect to the sensor's WiFi and upload firmware.
//

import Foundation
import Combine

class FirmwareUpdateManager: ObservableObject {
    // MARK: - Published State
    @Published var state: UpdateState = .idle
    
    enum UpdateState: Equatable {
        case idle
        case sentOTACommand       // BLE command sent, sensor entering AP mode
    }
    
    // MARK: - Configuration
    static let apSSID = "Pavloff-Update"
    static let apPassword = "pavloff123"
    static let uploadURL = "http://192.168.4.1"
    
    // MARK: - Public API
    
    /// Send the OTA command to the sensor via BLE.
    /// After this the sensor shuts down BLE and starts a WiFi AP.
    func sendOTACommand(bleManager: BLEManager, deviceId: UUID) {
        guard state == .idle else { return }
        
        print("[OTA] Sending OTA command via BLE...")
        bleManager.requestOTAMode(for: deviceId)
        state = .sentOTACommand
    }
    
    func reset() {
        state = .idle
    }
}
