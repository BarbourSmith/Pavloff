
//
//  DataDisplayView.swift
//  esp32Connect
//
//  Data display screen showing real-time IMU sensor data
//

import SwiftUI

struct DataDisplayView: View {
    @ObservedObject var bleManager: BLEManager
    let connectedDevices: [BLEDevice]
    
    @Environment(\.dismiss) var dismiss
    @State private var isMonitoring = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                Text("Workout Tracker")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // Device data cards
                ForEach(connectedDevices) { device in
                    if let deviceData = bleManager.deviceDataMap[device.id] {
                        DeviceDataCard(deviceData: deviceData)
                    }
                }
                
                // Stop monitoring button
                Button(action: {
                    stopMonitoring()
                }) {
                    Text("Stop Monitoring")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.98))
        .navigationTitle("Workout Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if isMonitoring {
                bleManager.disconnectAll()
            }
        }
    }
    
    private func stopMonitoring() {
        isMonitoring = false
        bleManager.disconnectAll()
        dismiss()
    }
}

struct DeviceDataCard: View {
    let deviceData: DeviceData
    
    var body: some View {
        VStack(spacing: 15) {
            // Device name
            Text(deviceData.name)
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 5)
            
            // Rep count data
            RepCountView(data: deviceData.accelData)
            
            // Last update timestamp
            Text("Last Update: \(deviceData.lastUpdate, formatter: timeFormatter)")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 5)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}

struct RepCountView: View {
    let data: SensorData
    
    var body: some View {
        VStack(spacing: 20) {
            // "REPS" label
            Text("REPS")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(.gray)
                .tracking(2)
            
            // Large rep count
            Text(data.formattedCount)
                .font(.system(size: 100, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Timestamp
            Text("Updated: \(data.formattedTimestamp)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 20)
    }
}

#Preview {
    DataDisplayView(
        bleManager: BLEManager(),
        connectedDevices: []
    )
}
