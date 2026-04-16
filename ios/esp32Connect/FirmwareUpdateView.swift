//
//  FirmwareUpdateView.swift
//  esp32Connect
//
//  UI for OTA firmware updates — sends BLE command then guides user
//  through WiFi connection and browser-based upload.
//

import SwiftUI

struct FirmwareUpdateView: View {
    @ObservedObject var bleManager: BLEManager
    let deviceId: UUID
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var updateManager = FirmwareUpdateManager()
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Current firmware info
                        firmwareInfoSection
                        
                        if updateManager.state == .idle {
                            instructionsPreview
                        } else {
                            stepsSection
                        }
                    }
                    .padding()
                }
                
                // Action buttons
                actionButtons
            }
            .background(Color(red: 0.97, green: 0.98, blue: 0.98))
            .navigationTitle("Firmware Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Enter Update Mode?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Continue") {
                    updateManager.sendOTACommand(bleManager: bleManager, deviceId: deviceId)
                }
            } message: {
                Text("The sensor will disconnect from Bluetooth and create a WiFi network. You will need to join that network and upload the firmware file in your browser.")
            }
        }
    }
    
    // MARK: - Sections
    
    private var firmwareInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Firmware")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Installed Version")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(bleManager.firmwareVersion ?? "Unknown")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var instructionsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Tapping \"Start Update Mode\" will put the sensor into firmware update mode. You'll then:")
                .font(.subheadline)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
            
            stepRow(number: 1, icon: "wifi", text: "Open Settings → WiFi and join \"\(FirmwareUpdateManager.apSSID)\"")
            stepRow(number: 2, icon: "safari", text: "Open Safari and go to \(FirmwareUpdateManager.uploadURL)")
            stepRow(number: 3, icon: "arrow.up.doc", text: "Select your .bin firmware file and tap Upload")
            stepRow(number: 4, icon: "checkmark.circle", text: "Wait for the update to complete — the sensor restarts automatically")
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update Mode Active")
                        .font(.body)
                        .fontWeight(.semibold)
                    Text("The sensor is now hosting a WiFi network.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            Text("Follow these steps:")
                .font(.headline)
                .fontWeight(.bold)
            
            stepRow(number: 1, icon: "wifi", text: "Open Settings → WiFi")
            
            VStack(alignment: .leading, spacing: 6) {
                stepRow(number: 2, icon: "lock.shield", text: "Join \"\(FirmwareUpdateManager.apSSID)\"")
                
                HStack(spacing: 4) {
                    Text("Password:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(FirmwareUpdateManager.apPassword)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.leading, 44)
            }
            
            stepRow(number: 3, icon: "safari", text: "Open Safari and visit:")
            
            Button(action: {
                if let url = URL(string: FirmwareUpdateManager.uploadURL) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "link")
                    Text(FirmwareUpdateManager.uploadURL)
                        .underline()
                }
                .font(.body)
                .foregroundColor(.blue)
            }
            .padding(.leading, 44)
            
            stepRow(number: 4, icon: "arrow.up.doc", text: "Select your .bin file and tap \"Upload & Install\"")
            stepRow(number: 5, icon: "checkmark.circle", text: "Wait for \"Update successful\" — the sensor restarts automatically")
            
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange)
                Text("After the update, reconnect to your normal WiFi network. The sensor will restart and be available via Bluetooth again.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 10) {
            if updateManager.state == .idle {
                Button(action: { showingConfirmation = true }) {
                    Text("Start Update Mode")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                Button(action: { dismiss() }) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white)
    }
    
    // MARK: - Helpers
    
    private func stepRow(number: Int, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
