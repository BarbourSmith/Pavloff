//
//  HomeView.swift
//  esp32Connect
//
//  Home screen for device scanning and selection
//

import SwiftUI

struct HomeView: View {
    @StateObject private var bleManager = BLEManager()
    @State private var selectedDevices: [BLEDevice] = []
    @State private var showingConnectionView = false
    @State private var scanError: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 15) {
                    Text("Select Devices (1 or 2)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Button(action: {
                        if bleManager.isScanning {
                            bleManager.stopScanning()
                        } else {
                            scanError = nil
                            if bleManager.bluetoothState != .poweredOn {
                                scanError = AppConfig.Errors.bluetoothOff
                            } else {
                                bleManager.startScanning()
                            }
                        }
                    }) {
                        Text(bleManager.isScanning ? "Stop Scan" : "Scan for Devices")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(bleManager.isScanning ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    if bleManager.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Scanning for devices... (\(Int(AppConfig.BLE.scanTimeout))s timeout)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .italic()
                        }
                        .padding(.top, 5)
                    }
                }
                .padding()
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.3)),
                    alignment: .bottom
                )
                
                // Error message
                if let error = scanError {
                    HStack {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 4)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(Color(red: 0.78, green: 0.16, blue: 0.16))
                            .padding(.vertical, 12)
                            .padding(.leading, 10)
                        
                        Spacer()
                    }
                    .background(Color(red: 1.0, green: 0.92, blue: 0.93))
                    .cornerRadius(8)
                    .padding()
                }
                
                // Device list
                if bleManager.discoveredDevices.isEmpty && !bleManager.isScanning {
                    Spacer()
                    Text("No devices found. Press \"Scan\" to begin.")
                        .foregroundColor(.gray)
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(bleManager.discoveredDevices) { device in
                                DeviceRow(
                                    device: device,
                                    isSelected: selectedDevices.contains(where: { $0.id == device.id }),
                                    onTap: {
                                        toggleDeviceSelection(device)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 100)
                    }
                }
                
                Spacer()
            }
            .background(Color(red: 0.97, green: 0.98, blue: 0.98))
            .overlay(
                // Footer
                VStack {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("\(selectedDevices.count) device(s) selected")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Button(action: {
                            if !selectedDevices.isEmpty {
                                showingConnectionView = true
                            }
                        }) {
                            Text("Proceed to Connect")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedDevices.isEmpty ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(selectedDevices.isEmpty)
                    }
                    .padding()
                    .background(Color.white)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.3)),
                        alignment: .top
                    )
                }
            )
            .navigationTitle("BLE Device Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showingConnectionView) {
                ConnectionView(
                    bleManager: bleManager,
                    selectedDevices: selectedDevices
                )
            }
        }
    }
    
    private func toggleDeviceSelection(_ device: BLEDevice) {
        if let index = selectedDevices.firstIndex(where: { $0.id == device.id }) {
            selectedDevices.remove(at: index)
        } else {
            if selectedDevices.count < AppConfig.Devices.maxSelectableDevices {
                selectedDevices.append(device)
            }
        }
    }
}

struct DeviceRow: View {
    let device: BLEDevice
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(device.id.uuidString)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
    }
}

#Preview {
    HomeView()
}
