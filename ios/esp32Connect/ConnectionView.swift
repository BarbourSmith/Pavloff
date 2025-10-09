import SwiftUI
import Combine

struct ConnectionView: View {
    @ObservedObject var bleManager: BLEManager
    let selectedDevices: [BLEDevice]
    
    @State private var showingDataView = false
    @State private var connectedDevices: [BLEDevice] = []
    
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            Text("Device Connection Status")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.vertical, 30)
            
            // Device status list
            VStack(spacing: 0) {
                ForEach(selectedDevices) { device in
                    HStack {
                        Text(device.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            if let status = bleManager.connectionStatuses[device.id] {
                                Text(status.displayText)
                                    .font(.body)
                                    .foregroundColor(statusColor(for: status))
                                
                                if isConnecting(status) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            } else {
                                Text("Pending...")
                                    .font(.body)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 10)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color.gray.opacity(0.2)),
                        alignment: .bottom
                    )
                }
            }
            .background(Color.white)
            .cornerRadius(8)
            .padding()
            
            Spacer()
            
            // Show Data button
            Button(action: {
                showingDataView = true
            }) {
                Text("Show Data for \(connectedDevices.count) Device(s)")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(connectedDevices.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(connectedDevices.isEmpty)
            .padding()
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.98))
        .navigationTitle("Connecting...")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            connectToDevices()
        }
        .onChange(of: bleManager.connectionStatuses) { _ in
            updateConnectedDevices()
        }
    }
    
    var body: some View {
        if #available(iOS 16.0, *) {
            content
                .navigationDestination(isPresented: $showingDataView) {
                    DataDisplayView(
                        bleManager: bleManager,
                        connectedDevices: connectedDevices
                    )
                }
        } else {
            ZStack {
                content
                NavigationLink(
                    destination: DataDisplayView(
                        bleManager: bleManager,
                        connectedDevices: connectedDevices
                    ),
                    isActive: $showingDataView
                ) { EmptyView() }
                .hidden()
            }
        }
    }
    
    private func connectToDevices() {
        for device in selectedDevices {
            bleManager.connect(to: device)
        }
    }
    
    private func updateConnectedDevices() {
        connectedDevices = selectedDevices.filter { device in
            if case .connected = bleManager.connectionStatuses[device.id] {
                return true
            }
            return false
        }
    }
    
    private func statusColor(for status: ConnectionStatus) -> Color {
        switch status {
        case .connected:
            return .green
        case .failed:
            return .red
        default:
            return .gray
        }
    }
    
    private func isConnecting(_ status: ConnectionStatus) -> Bool {
        switch status {
        case .connecting, .discovering:
            return true
        default:
            return false
        }
    }
}
