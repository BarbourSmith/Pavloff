//
//  AutoConnectDataDisplayView.swift
//  esp32Connect
//
//  Single-screen auto-connecting data display view
//

import SwiftUI
import CoreBluetooth

struct AutoConnectDataDisplayView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var connectionStatus: String = "Scanning for device..."
    @State private var isConnected: Bool = false
    @State private var connectedDevice: BLEDevice?
    @State private var scanTimer: Timer?
    
    private let targetDeviceName = "ESP32_IMU_Stream"
    private let scanInterval: TimeInterval = 5.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                Text("Exercise Rep Counter")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack {
                    if !isConnected {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(connectionStatus)
                        .font(.subheadline)
                        .foregroundColor(isConnected ? Color.white.opacity(0.9) : Color.white.opacity(0.8))
                        .font(isConnected ? .subheadline.weight(.semibold) : .subheadline.weight(.regular))
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            
            // Content area
            ScrollView {
                if isConnected, let device = connectedDevice {
                    // Show rep counter when connected
                    VStack(spacing: 20) {
                        Text(device.name)
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.top, 25)
                        
                        if let deviceData = bleManager.deviceDataMap[device.id] {
                            RepCountView(data: deviceData.accelData)
                                .padding()
                        }
                    }
                } else {
                    // Show waiting message when not connected
                    VStack(spacing: 20) {
                        Spacer()
                            .frame(height: 60)
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom, 20)
                        
                        Text("Waiting for \(targetDeviceName)")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Text("to be available...")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        Text("Make sure your device is powered on and in range.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 10)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.white)
        }
        .onAppear {
            startAutoConnect()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    private func startAutoConnect() {
        print("[AUTO-CONNECT] Starting auto-connect for \(targetDeviceName)")
        
        // Start initial scan
        scanForTargetDevice()
        
        // Set up periodic scanning when not connected
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { _ in
            if !isConnected {
                print("[AUTO-CONNECT] Periodic scan triggered")
                scanForTargetDevice()
            }
        }
    }
    
    private func scanForTargetDevice() {
        guard bleManager.bluetoothState == .poweredOn else {
            connectionStatus = "Bluetooth is \(bleManager.bluetoothState.description). Please enable Bluetooth."
            print("[AUTO-CONNECT] Bluetooth not powered on: \(bleManager.bluetoothState)")
            return
        }
        
        guard !isConnected else {
            print("[AUTO-CONNECT] Already connected, skipping scan")
            return
        }
        
        connectionStatus = "Scanning for \(targetDeviceName)..."
        print("[AUTO-CONNECT] Scanning for \(targetDeviceName)...")
        
        // Clear previous devices
        bleManager.discoveredDevices.removeAll()
        
        // Start scanning
        bleManager.startScanning()
        
        // Check for target device after scan timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.BLE.scanTimeout) {
            bleManager.stopScanning()
            
            // Look for target device
            if let targetDevice = bleManager.discoveredDevices.first(where: { $0.name == targetDeviceName }) {
                print("[AUTO-CONNECT] Target device found!")
                connectToDevice(targetDevice)
            } else if !isConnected {
                print("[AUTO-CONNECT] Target device not found, will retry...")
                connectionStatus = "\(targetDeviceName) not found. Will retry..."
            }
        }
    }
    
    private func connectToDevice(_ device: BLEDevice) {
        connectionStatus = "Connecting to \(device.name)..."
        print("[AUTO-CONNECT] Attempting to connect to \(device.name)")
        
        // Connect to device
        bleManager.connect(to: device)
        
        // Monitor connection status
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            checkConnectionStatus(device)
        }
    }
    
    private func checkConnectionStatus(_ device: BLEDevice) {
        if let status = bleManager.connectionStatuses[device.id] {
            switch status {
            case .connected:
                isConnected = true
                connectedDevice = device
                connectionStatus = "Connected to \(device.name)"
                print("[AUTO-CONNECT] Successfully connected to \(device.name)")
                
            case .pending, .connecting, .discovering:
                // Still connecting, check again later
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    checkConnectionStatus(device)
                }
                
            case .disconnected, .failed:
                print("[AUTO-CONNECT] Connection failed, will retry...")
                connectionStatus = "Connection failed. Retrying..."
                isConnected = false
                connectedDevice = nil
                
                // Disconnect cleanly
                bleManager.disconnect(from: device.id)
            }
        } else {
            // No status yet, check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkConnectionStatus(device)
            }
        }
    }
    
    private func cleanup() {
        print("[AUTO-CONNECT] Cleaning up...")
        scanTimer?.invalidate()
        scanTimer = nil
        bleManager.stopScanning()
        bleManager.disconnectAll()
    }
}

// Extension to get string description of CBManagerState
extension CBManagerState {
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .resetting: return "Resetting"
        case .unsupported: return "Unsupported"
        case .unauthorized: return "Unauthorized"
        case .poweredOff: return "PoweredOff"
        case .poweredOn: return "PoweredOn"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    AutoConnectDataDisplayView()
}
