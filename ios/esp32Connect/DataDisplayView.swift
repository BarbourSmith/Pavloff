
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
                Text("Live IMU Data")
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
        .navigationTitle("Live IMU Data")
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
            
            // Accelerometer data
            SensorDataView(
                title: "Accelerometer",
                data: deviceData.accelData,
                color: .blue
            )
            
            Divider()
            
            // Gyroscope data
            SensorDataView(
                title: "Gyroscope",
                data: deviceData.gyroData,
                color: .green
            )
            
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

struct SensorDataView: View {
    let title: String
    let data: SensorData
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                // X axis
                VStack(spacing: 4) {
                    Text("X")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text(data.formattedX)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.1))
                .cornerRadius(8)
                
                // Y axis
                VStack(spacing: 4) {
                    Text("Y")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text(data.formattedY)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.1))
                .cornerRadius(8)
                
                // Z axis
                VStack(spacing: 4) {
                    Text("Z")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    
                    Text(data.formattedZ)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(color.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Timestamp
            Text("Updated: \(data.formattedTimestamp)")
                .font(.caption2)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    DataDisplayView(
        bleManager: BLEManager(),
        connectedDevices: []
    )
}
