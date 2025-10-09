//
//  BLEManager.swift
//  esp32Connect
//
//  Bluetooth LE Manager for device scanning, connection, and data monitoring
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - IMU Integrator
class IMUIntegrator {
    private var velocity: (x: Double, y: Double, z: Double) = (0, 0, 0)
    private var position: (x: Double, y: Double, z: Double) = (0, 0, 0)
    private var lastTimestamp: Date?
    private var lastAccel: (x: Double, y: Double, z: Double) = (0, 0, 0)
    
    func reset() {
        velocity = (0, 0, 0)
        position = (0, 0, 0)
        lastTimestamp = nil
        lastAccel = (0, 0, 0)
    }
    
    func integrate(accel: SensorData) -> PositionData {
        let currentTime = accel.timestamp
        
        // Initialize on first call
        guard let lastTime = lastTimestamp else {
            lastTimestamp = currentTime
            lastAccel = (accel.x, accel.y, accel.z)
            return PositionData(x: position.x, y: position.y, z: position.z)
        }
        
        // Calculate time delta
        let dt = currentTime.timeIntervalSince(lastTime)
        
        // Prevent integration with unrealistic time deltas
        guard dt > 0 && dt < 1.0 else {
            lastTimestamp = currentTime
            return PositionData(x: position.x, y: position.y, z: position.z)
        }
        
        // Gravity compensation (assuming Z-axis is vertical)
        let azCompensated = accel.z - 9.81
        
        // Trapezoidal integration for velocity
        velocity.x += (lastAccel.x + accel.x) * dt / 2
        velocity.y += (lastAccel.y + accel.y) * dt / 2
        velocity.z += (lastAccel.z + azCompensated) * dt / 2
        
        // Apply velocity dampening to reduce drift
        let damping = 0.98
        velocity.x *= damping
        velocity.y *= damping
        velocity.z *= damping
        
        // Integrate velocity to get position
        position.x += velocity.x * dt
        position.y += velocity.y * dt
        position.z += velocity.z * dt
        
        // Update last values
        lastAccel = (accel.x, accel.y, azCompensated)
        lastTimestamp = currentTime
        
        return PositionData(x: position.x, y: position.y, z: position.z)
    }
}

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
    private var integrators: [UUID: IMUIntegrator] = [:]
    
    // MARK: - UUIDs
    private let imuServiceUUID = CBUUID(string: AppConfig.UUIDs.imuService)
    private let accelCharUUID = CBUUID(string: AppConfig.UUIDs.accelCharacteristic)
    private let gyroCharUUID = CBUUID(string: AppConfig.UUIDs.gyroCharacteristic)
    
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
    
    /// Parse sensor data from characteristic value
    private func parseSensorData(from data: Data) -> SensorData? {
        guard let dataString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        var values: [String: Double] = [:]
        
        // Parse format: "X:value,Y:value,Z:value"
        let components = dataString.split(separator: ",")
        for component in components {
            let keyValue = component.split(separator: ":")
            if keyValue.count == 2,
               let key = keyValue.first?.trimmingCharacters(in: .whitespaces).lowercased(),
               let valueStr = keyValue.last?.trimmingCharacters(in: .whitespaces),
               let value = Double(valueStr) {
                values[key] = value
            }
        }
        
        return SensorData(
            x: values["x"] ?? 0.0,
            y: values["y"] ?? 0.0,
            z: values["z"] ?? 0.0,
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
        
        // Identify characteristics
        for characteristic in characteristics {
            print("[BLE] Characteristic UUID: \(characteristic.uuid)")
            
            if characteristic.uuid == accelCharUUID {
                discoveredChars.accelUUID = characteristic.uuid
                print("[BLE] Found accelerometer characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == gyroCharUUID {
                discoveredChars.gyroUUID = characteristic.uuid
                print("[BLE] Found gyroscope characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // Fallback: use position-based assignment if UUIDs don't match
        if !discoveredChars.isComplete && characteristics.count >= 2 {
            print("[BLE] Using position-based characteristic assignment")
            discoveredChars.accelUUID = characteristics[0].uuid
            discoveredChars.gyroUUID = characteristics[1].uuid
            
            for characteristic in characteristics {
                peripheral.setNotifyValue(true, for: characteristic)
            }
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
            if var deviceData = self.deviceDataMap[peripheral.identifier] {
                // Update appropriate sensor data
                if characteristic.uuid == chars.accelUUID {
                    deviceData.accelData = sensorData
                    
                    // Initialize integrator if needed
                    if self.integrators[peripheral.identifier] == nil {
                        self.integrators[peripheral.identifier] = IMUIntegrator()
                    }
                    
                    // Integrate acceleration to get position
                    if let integrator = self.integrators[peripheral.identifier] {
                        deviceData.positionData = integrator.integrate(accel: sensorData)
                    }
                    
                    print("[BLE] Accel data from \(peripheral.name ?? "Unknown"): X:\(sensorData.formattedX), Y:\(sensorData.formattedY), Z:\(sensorData.formattedZ)")
                    print("[BLE] Position from \(peripheral.name ?? "Unknown"): X:\(deviceData.positionData.formattedX)m, Y:\(deviceData.positionData.formattedY)m, Z:\(deviceData.positionData.formattedZ)m")
                } else if characteristic.uuid == chars.gyroUUID {
                    deviceData.gyroData = sensorData
                    print("[BLE] Gyro data from \(peripheral.name ?? "Unknown"): X:\(sensorData.formattedX), Y:\(sensorData.formattedY), Z:\(sensorData.formattedZ)")
                }
                
                deviceData.lastUpdate = Date()
                self.deviceDataMap[peripheral.identifier] = deviceData
            }
        }
    }
}
