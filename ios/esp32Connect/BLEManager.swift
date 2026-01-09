//
//  BLEManager.swift
//  esp32Connect
//
//  Bluetooth LE Manager for device scanning, connection, and data monitoring
//

import Foundation
import CoreBluetooth
import Combine

class BLEManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var discoveredDevices: [BLEDevice] = []
    @Published var isScanning = false
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var connectionStatuses: [UUID: ConnectionStatus] = [:]
    @Published var deviceDataMap: [UUID: DeviceData] = [:]
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var characteristicMap: [UUID: DiscoveredCharacteristics] = [:]
    private var scanTimer: Timer?
    
    // MARK: - UUIDs
    private let imuServiceUUID = CBUUID(string: AppConfig.UUIDs.imuService)
    private let accelCharUUID = CBUUID(string: AppConfig.UUIDs.accelCharacteristic)
    private let gyroCharUUID = CBUUID(string: AppConfig.UUIDs.gyroCharacteristic)
    private let durationCharUUID = CBUUID(string: AppConfig.UUIDs.durationCharacteristic)
    private let sensitivityCharUUID = CBUUID(string: AppConfig.UUIDs.sensitivityCharacteristic)
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for BLE devices
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("[BLE] Cannot scan - Bluetooth is not powered on")
            return
        }
        
        print("[BLE] Starting device scan...")
        discoveredDevices.removeAll()
        isScanning = true
        
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        
        // Stop scanning after timeout
        scanTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.BLE.scanTimeout, repeats: false) { [weak self] _ in
            self?.stopScanning()
        }
    }
    
    /// Start scanning for BLE devices without internal timeout (for external timeout management)
    func startScanningWithoutTimeout() {
        guard centralManager.state == .poweredOn else {
            print("[BLE] Cannot scan - Bluetooth is not powered on")
            return
        }
        
        print("[BLE] Starting device scan...")
        discoveredDevices.removeAll()
        isScanning = true
        
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    /// Stop scanning for BLE devices
    func stopScanning() {
        print("[BLE] Stopping device scan")
        centralManager.stopScan()
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    /// Connect to a device
    func connect(to device: BLEDevice) {
        print("[BLE] Connecting to device: \(device.name)")
        connectionStatuses[device.id] = .connecting
        centralManager.connect(device.peripheral, options: nil)
    }
    
    /// Disconnect from a device
    func disconnect(from deviceId: UUID) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            print("[BLE] No peripheral found for device ID: \(deviceId)")
            return
        }
        
        print("[BLE] Disconnecting from device: \(peripheral.name ?? "Unknown")")
        centralManager.cancelPeripheralConnection(peripheral)
        connectedPeripherals.removeValue(forKey: deviceId)
        characteristicMap.removeValue(forKey: deviceId)
        deviceDataMap.removeValue(forKey: deviceId)
        connectionStatuses.removeValue(forKey: deviceId)
    }
    
    /// Disconnect from all devices
    func disconnectAll() {
        let deviceIds = Array(connectedPeripherals.keys)
        for deviceId in deviceIds {
            disconnect(from: deviceId)
        }
    }
    
    /// Reset rep count for a connected device
    func resetRepCount(for deviceId: UUID) {
        guard let peripheral = connectedPeripherals[deviceId],
              let chars = characteristicMap[deviceId],
              let repCharUUID = chars.accelUUID else {
            print("[BLE] Cannot reset - device or characteristic not found")
            return
        }
        
        // Find the rep characteristic
        guard let service = peripheral.services?.first(where: { $0.uuid == imuServiceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid == repCharUUID }) else {
            print("[BLE] Cannot find rep characteristic for reset")
            return
        }
        
        // Send RESET command
        let resetData = "RESET".data(using: .utf8)!
        peripheral.writeValue(resetData, for: characteristic, type: .withResponse)
        print("[BLE] Sent RESET command to device: \(peripheral.name ?? "Unknown")")
    }
    
    /// Send sensitivity settings to a connected device
    func sendSensitivitySettings(for deviceId: UUID, repSensitivity: Double, vibrationSensitivity: Double) {
        guard let peripheral = connectedPeripherals[deviceId] else {
            print("[BLE] Cannot send sensitivity - device not found")
            return
        }
        
        // Find the sensitivity characteristic
        guard let service = peripheral.services?.first(where: { $0.uuid == imuServiceUUID }),
              let characteristic = service.characteristics?.first(where: { $0.uuid == sensitivityCharUUID }) else {
            print("[BLE] Cannot find sensitivity characteristic")
            return
        }
        
        // Format: "RepSens:value,VibSens:value"
        let sensitivityString = String(format: "RepSens:%.2f,VibSens:%.2f", repSensitivity, vibrationSensitivity)
        guard let sensitivityData = sensitivityString.data(using: .utf8) else {
            print("[BLE] Failed to encode sensitivity data")
            return
        }
        
        peripheral.writeValue(sensitivityData, for: characteristic, type: .withResponse)
        print("[BLE] Sent sensitivity settings to device: \(peripheral.name ?? "Unknown") - Rep: \(repSensitivity), Vib: \(vibrationSensitivity)")
    }
    
    /// Parse sensor data from characteristic value
    private func parseSensorData(from data: Data) -> SensorData? {
        guard let dataString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        var count: Int = 0
        var state: String = "IDLE"
        var duration: Int = 0
        
        // Parse format: "Count:value,State:value,Duration:value"
        // Example: "Count:5,State:UP" or "Count:12,State:DOWN" or "Duration:45,State:ACTIVE"
        let components = dataString.split(separator: ",")
        
        for component in components {
            let keyValue = component.split(separator: ":")
            if keyValue.count == 2 {
                let key = keyValue.first?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
                let valueStr = keyValue.last?.trimmingCharacters(in: .whitespaces) ?? ""
                
                if key == "count", let countValue = Int(valueStr) {
                    count = countValue
                } else if key == "state" {
                    state = valueStr
                } else if key == "duration", let durationValue = Int(valueStr) {
                    duration = durationValue
                }
            }
        }
        
        return SensorData(
            count: count,
            state: state,
            duration: duration,
            timestamp: Date()
        )
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.bluetoothState = central.state
            print("[BLE] Bluetooth state updated: \(central.state.rawValue)")
            
            if central.state != .poweredOn && self.isScanning {
                self.stopScanning()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // Only add devices with names
        guard let name = peripheral.name, !name.isEmpty else {
            return
        }
        
        // Check if device already exists
        if !discoveredDevices.contains(where: { $0.id == peripheral.identifier }) {
            let device = BLEDevice(
                id: peripheral.identifier,
                name: name,
                peripheral: peripheral,
                rssi: RSSI.intValue
            )
            
            DispatchQueue.main.async {
                self.discoveredDevices.append(device)
                print("[BLE] Discovered device: \(name) (\(peripheral.identifier))")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[BLE] Connected to: \(peripheral.name ?? "Unknown")")
        
        DispatchQueue.main.async {
            self.connectionStatuses[peripheral.identifier] = .discovering
            self.connectedPeripherals[peripheral.identifier] = peripheral
        }
        
        peripheral.delegate = self
        peripheral.discoverServices([imuServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[BLE] Failed to connect to: \(peripheral.name ?? "Unknown"), error: \(error?.localizedDescription ?? "unknown")")
        
        DispatchQueue.main.async {
            self.connectionStatuses[peripheral.identifier] = .failed(error?.localizedDescription ?? "Connection failed")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[BLE] Disconnected from: \(peripheral.name ?? "Unknown")")
        
        DispatchQueue.main.async {
            self.connectedPeripherals.removeValue(forKey: peripheral.identifier)
            self.characteristicMap.removeValue(forKey: peripheral.identifier)
            self.deviceDataMap.removeValue(forKey: peripheral.identifier)
            self.connectionStatuses.removeValue(forKey: peripheral.identifier)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("[BLE] Error discovering services: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.connectionStatuses[peripheral.identifier] = .failed("Service discovery failed")
            }
            return
        }
        
        guard let services = peripheral.services else {
            print("[BLE] No services found")
            DispatchQueue.main.async {
                self.connectionStatuses[peripheral.identifier] = .failed("No services found")
            }
            return
        }
        
        print("[BLE] Discovered \(services.count) services")
        
        // Find IMU service
        if let imuService = services.first(where: { $0.uuid == imuServiceUUID }) {
            print("[BLE] Found IMU service, discovering characteristics...")
            peripheral.discoverCharacteristics(nil, for: imuService)
        } else {
            print("[BLE] IMU service not found")
            DispatchQueue.main.async {
                self.connectionStatuses[peripheral.identifier] = .failed("IMU service not found")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("[BLE] Error discovering characteristics: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.connectionStatuses[peripheral.identifier] = .failed("Characteristic discovery failed")
            }
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("[BLE] No characteristics found")
            DispatchQueue.main.async {
                self.connectionStatuses[peripheral.identifier] = .failed("No characteristics found")
            }
            return
        }
        
        print("[BLE] Discovered \(characteristics.count) characteristics")
        
        var discoveredChars = DiscoveredCharacteristics()
        
        // Identify characteristics - looking for rep count and duration characteristics
        for characteristic in characteristics {
            if characteristic.uuid == accelCharUUID {
                discoveredChars.accelUUID = characteristic.uuid
                print("[BLE] Found rep count characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == durationCharUUID {
                print("[BLE] Found duration characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // Fallback: use first characteristic for rep count if UUID doesn't match
        if discoveredChars.accelUUID == nil && characteristics.count >= 1 {
            print("[BLE] Using first available characteristic")
            discoveredChars.accelUUID = characteristics[0].uuid
            peripheral.setNotifyValue(true, for: characteristics[0])
        }
        
        // Set gyroUUID to the same as accelUUID for compatibility (not used for display)
        if discoveredChars.accelUUID != nil {
            discoveredChars.gyroUUID = discoveredChars.accelUUID
        }
        
        DispatchQueue.main.async {
            self.characteristicMap[peripheral.identifier] = discoveredChars
            
            if discoveredChars.isComplete {
                self.connectionStatuses[peripheral.identifier] = .connected
                
                // Initialize device data
                if let name = peripheral.name {
                    self.deviceDataMap[peripheral.identifier] = DeviceData(id: peripheral.identifier, name: name)
                }
                
                print("[BLE] Device fully connected and ready: \(peripheral.name ?? "Unknown")")
            } else {
                self.connectionStatuses[peripheral.identifier] = .failed("Characteristics incomplete")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLE] Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        print("[BLE] Notification state updated for characteristic: \(characteristic.uuid), isNotifying: \(characteristic.isNotifying)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[BLE] Error updating value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value,
              let sensorData = parseSensorData(from: data),
              let chars = characteristicMap[peripheral.identifier] else {
            return
        }
        
        DispatchQueue.main.async {
            // Ensure device data exists
            if self.deviceDataMap[peripheral.identifier] == nil {
                self.deviceDataMap[peripheral.identifier] = DeviceData(
                    id: peripheral.identifier,
                    name: peripheral.name ?? "Unknown Device"
                )
            }
            
            if var deviceData = self.deviceDataMap[peripheral.identifier] {
                // Merge sensor data intelligently to avoid flickering
                // Rep characteristic contains count and state
                // Duration characteristic contains duration and state
                // We merge the data to preserve both values
                if characteristic.uuid == chars.accelUUID {
                    // Rep characteristic: update count and state, but preserve duration
                    var mergedData = deviceData.accelData
                    mergedData.count = sensorData.count
                    mergedData.state = sensorData.state
                    mergedData.timestamp = sensorData.timestamp
                    // Keep existing duration value
                    deviceData.accelData = mergedData
                } else if characteristic.uuid == self.durationCharUUID {
                    // Duration characteristic: update duration and state, but preserve count
                    var mergedData = deviceData.accelData
                    mergedData.duration = sensorData.duration
                    mergedData.state = sensorData.state
                    mergedData.timestamp = sensorData.timestamp
                    // Keep existing count value
                    deviceData.accelData = mergedData
                }
                
                deviceData.lastUpdate = Date()
                self.deviceDataMap[peripheral.identifier] = deviceData
            }
        }
    }
}
