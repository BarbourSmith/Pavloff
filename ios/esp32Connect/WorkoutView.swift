//
//  WorkoutView.swift
//  esp32Connect
//
//  Main workout screen showing current exercise and rep tracking
//

import SwiftUI
import CoreBluetooth
import UIKit

struct WorkoutView: View {
    @StateObject private var bleManager = BLEManager()
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @StateObject private var streakManager = StreakManager.shared
    @State private var workoutSettings = WorkoutSettings()
    @State private var currentExerciseIndex = 0
    @State private var connectionStatus: String = "Scanning for device..."
    @State private var isConnected: Bool = false
    @State private var connectedDevice: BLEDevice?
    @State private var scanTimer: Timer?
    @State private var isScanning: Bool = false
    @State private var showingSetup = false
    @State private var showingCongratulations = false
    @State private var lastRepCount = 0
    @State private var workoutStartedToday = false
    
    // Accept both old and new device names for backward compatibility
    private let targetDeviceNames = ["Pavloff Workout Sensor", "ESP32_IMU_Stream"]
    private let scanInterval: TimeInterval = 5.0
    
    // Notification observers
    @State private var scenePhaseObserver: NSObjectProtocol?
    @State private var timeChangeObserver: NSObjectProtocol?
    
    private var currentExercise: Exercise {
        workoutSettings.exercises[currentExerciseIndex]
    }
    
    private var currentReps: Int {
        if let device = connectedDevice,
           let deviceData = bleManager.deviceDataMap[device.id] {
            return deviceData.accelData.count
        }
        return 0
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Text("Workout Tracker")
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
                    
                    // Streak Indicator
                    if streakManager.currentStreak > 0 {
                        HStack(spacing: 6) {
                            Text("🔥")
                                .font(.system(size: 16))
                            Text("\(streakManager.currentStreak) day streak")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.3))
                        .cornerRadius(12)
                    }
                    
                    // Screen Time Status Indicator
                    if screenTimeManager.isAuthorized && screenTimeManager.hasAppsSelected {
                        HStack(spacing: 6) {
                            Image(systemName: workoutStartedToday ? "lock.open.fill" : "lock.fill")
                                .font(.caption)
                            Text(workoutStartedToday ? "Apps Unlocked" : "Apps Blocked")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(workoutStartedToday ? Color.green.opacity(0.3) : Color.orange.opacity(0.3))
                        .cornerRadius(12)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                
                // Content area
                ScrollView {
                    if isConnected {
                        // Show workout tracking when connected
                        VStack(spacing: 25) {
                            // Exercise progress indicator
                            HStack(spacing: 8) {
                                ForEach(0..<workoutSettings.exercises.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentExerciseIndex ? Color.blue : 
                                              index < currentExerciseIndex ? Color.green : Color.gray.opacity(0.3))
                                        .frame(width: 12, height: 12)
                                }
                            }
                            .padding(.top, 20)
                            
                            // Current exercise name
                            VStack(spacing: 8) {
                                Text("Current Exercise")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                
                                Text(currentExercise.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            .padding(.top, 10)
                            
                            // Rep counter
                            VStack(spacing: 15) {
                                Text("REPS")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.gray)
                                    .tracking(2)
                                
                                // Current reps / Target reps
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("\(currentReps)")
                                        .font(.system(size: 80, weight: .bold, design: .rounded))
                                        .foregroundColor(.blue)
                                    
                                    Text("/")
                                        .font(.system(size: 40, weight: .semibold))
                                        .foregroundColor(.gray)
                                    
                                    Text("\(currentExercise.targetReps)")
                                        .font(.system(size: 40, weight: .semibold))
                                        .foregroundColor(.gray)
                                }
                                
                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                            .cornerRadius(4)
                                        
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: min(CGFloat(currentReps) / CGFloat(currentExercise.targetReps), 1.0) * geometry.size.width, height: 8)
                                            .cornerRadius(4)
                                            .animation(.easeInOut(duration: 0.3), value: currentReps)
                                    }
                                }
                                .frame(height: 8)
                                .padding(.horizontal, 40)
                            }
                            .padding(.vertical, 30)
                            
                            // Exercise status
                            if let device = connectedDevice,
                               let deviceData = bleManager.deviceDataMap[device.id] {
                                Text(deviceData.accelData.formattedState)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .tracking(1)
                                    .padding(.horizontal, 30)
                                    .padding(.vertical, 12)
                                    .background(stateColor(deviceData.accelData.state))
                                    .cornerRadius(25)
                            }
                            
                            Spacer()
                                .frame(height: 30)
                            
                            // Control buttons
                            VStack(spacing: 12) {
                                // Settings button
                                Button(action: {
                                    showingSetup = true
                                }) {
                                    HStack {
                                        Image(systemName: "gearshape.fill")
                                        Text("Workout Settings")
                                    }
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                                
                                // Reset button
                                Button(action: {
                                    resetCurrentExercise()
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Reset Exercise")
                                    }
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Show waiting message when not connected
                        VStack(spacing: 20) {
                            Spacer()
                                .frame(height: 60)
                            
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding(.bottom, 20)
                            
                            Text("Waiting for sensor...")
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
                            
                            // Settings button (available even when not connected)
                            Button(action: {
                                showingSetup = true
                            }) {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                    Text("Workout Settings")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: 200)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding(.top, 30)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(Color.white)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingSetup) {
                SetupView(workoutSettings: $workoutSettings)
            }
            .sheet(isPresented: $showingCongratulations) {
                CongratulationsView(workoutSettings: workoutSettings, onRestart: {
                    restartWorkout()
                })
            }
            .onAppear {
                startAutoConnect()
                checkAndEnableScreenTimeBlocking()
                setupNotificationObservers()
            }
            .onDisappear {
                cleanup()
                removeNotificationObservers()
            }
            .onChange(of: bleManager.connectionStatuses) { _ in
                // Monitor for disconnections
                if isConnected, let device = connectedDevice {
                    if let status = bleManager.connectionStatuses[device.id] {
                        if case .disconnected = status {
                            handleDisconnection()
                        } else if case .failed = status {
                            handleDisconnection()
                        }
                    } else {
                        handleDisconnection()
                    }
                }
            }
            .onChange(of: currentReps) { newReps in
                // Check if target reached
                if newReps >= currentExercise.targetReps && newReps > lastRepCount {
                    exerciseCompleted()
                }
                lastRepCount = newReps
            }
        }
    }
    
    private func stateColor(_ state: String) -> Color {
        switch state.uppercased() {
        case "UP":
            return .green
        case "DOWN":
            return .blue
        case "IDLE":
            return .gray
        default:
            return .orange
        }
    }
    
    private func exerciseCompleted() {
        print("[WORKOUT] Exercise completed: \(currentExercise.name)")
        
        // Move to next exercise
        if currentExerciseIndex < workoutSettings.exercises.count - 1 {
            currentExerciseIndex += 1
            resetCurrentExercise()
        } else {
            // All exercises completed
            print("[WORKOUT] All exercises completed!")
            workoutCompletedToday()
            showingCongratulations = true
        }
    }
    
    private func resetCurrentExercise() {
        if let device = connectedDevice {
            bleManager.resetRepCount(for: device.id)
            lastRepCount = 0
        }
    }
    
    private func restartWorkout() {
        currentExerciseIndex = 0
        resetCurrentExercise()
        showingCongratulations = false
        checkAndEnableScreenTimeBlocking()
    }
    
    private func checkAndEnableScreenTimeBlocking() {
        // Check if workout was completed today
        let lastCompletionDate = UserDefaults.standard.object(forKey: "lastWorkoutCompletion") as? Date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastDate = lastCompletionDate {
            let lastCompletionDay = calendar.startOfDay(for: lastDate)
            workoutStartedToday = calendar.isDate(lastCompletionDay, inSameDayAs: today)
        } else {
            workoutStartedToday = false
        }
        
        // Enable blocking if workout not completed today
        if !workoutStartedToday {
            print("[WORKOUT] Workout not completed today, enabling app blocking")
            screenTimeManager.enableAppBlocking()
        } else {
            print("[WORKOUT] Workout already completed today, apps remain unblocked")
        }
    }
    
    private func workoutCompletedToday() {
        // Save completion time
        UserDefaults.standard.set(Date(), forKey: "lastWorkoutCompletion")
        workoutStartedToday = true
        
        // Update streak
        streakManager.checkAndUpdateStreak()
        
        // Disable app blocking for the rest of the day
        print("[WORKOUT] Workout completed! Disabling app blocking")
        screenTimeManager.disableAppBlocking()
    }
    
    private func setupNotificationObservers() {
        // Listen for when app becomes active (returns from background or launches)
        scenePhaseObserver = NotificationCenter.default.addObserver(
            forName: UIScene.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[WORKOUT] App entering foreground, rechecking app blocking status")
            self?.checkAndEnableScreenTimeBlocking()
        }
        
        // Listen for significant time changes (like passing midnight)
        timeChangeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[WORKOUT] Significant time change detected (midnight crossed), rechecking app blocking status")
            self?.checkAndEnableScreenTimeBlocking()
        }
    }
    
    private func removeNotificationObservers() {
        if let observer = scenePhaseObserver {
            NotificationCenter.default.removeObserver(observer)
            scenePhaseObserver = nil
        }
        
        if let observer = timeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            timeChangeObserver = nil
        }
    }
    
    private func handleDisconnection() {
        print("[WORKOUT] Device disconnected, resuming scan...")
        isConnected = false
        connectedDevice = nil
        connectionStatus = "Device disconnected. Reconnecting..."
        // Re-enable screen sleep when disconnected
        UIApplication.shared.isIdleTimerDisabled = false
        print("[WORKOUT] Screen idle timer re-enabled")
    }
    
    private func startAutoConnect() {
        print("[WORKOUT] Starting auto-connect for Pavloff sensors")
        
        scanForTargetDevice()
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { _ in
            if !isConnected {
                print("[WORKOUT] Periodic scan triggered")
                scanForTargetDevice()
            }
        }
    }
    
    private func scanForTargetDevice() {
        guard bleManager.bluetoothState == .poweredOn else {
            connectionStatus = "Bluetooth is \(bleManager.bluetoothState.stateDescription). Please enable Bluetooth."
            print("[WORKOUT] Bluetooth not powered on: \(bleManager.bluetoothState)")
            return
        }
        
        guard !isConnected else {
            print("[WORKOUT] Already connected, skipping scan")
            return
        }
        
        guard !isScanning else {
            print("[WORKOUT] Scan already in progress, skipping")
            return
        }
        
        isScanning = true
        connectionStatus = "Scanning for sensor..."
        print("[WORKOUT] Scanning for Pavloff sensors...")
        
        bleManager.discoveredDevices.removeAll()
        bleManager.startScanningWithoutTimeout()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.BLE.scanTimeout) {
            self.isScanning = false
            bleManager.stopScanning()
            
            // Look for device with any of the accepted names
            if let targetDevice = bleManager.discoveredDevices.first(where: { device in
                self.targetDeviceNames.contains(device.name)
            }) {
                print("[WORKOUT] Target device found: \(targetDevice.name)")
                self.connectionStatus = "Found \(targetDevice.name)"
                self.connectToDevice(targetDevice)
            } else if !self.isConnected {
                print("[WORKOUT] Target device not found, will retry...")
                self.connectionStatus = "Device not found. Will retry..."
            }
        }
    }
    
    private func connectToDevice(_ device: BLEDevice) {
        connectionStatus = "Connecting to \(device.name)..."
        print("[WORKOUT] Attempting to connect to \(device.name)")
        
        bleManager.connect(to: device)
        
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
                print("[WORKOUT] Successfully connected to \(device.name)")
                // Prevent screen from sleeping during workout
                UIApplication.shared.isIdleTimerDisabled = true
                print("[WORKOUT] Screen idle timer disabled")
                
            case .pending, .connecting, .discovering:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    checkConnectionStatus(device)
                }
                
            case .disconnected, .failed:
                print("[WORKOUT] Connection failed, will retry...")
                connectionStatus = "Connection failed. Retrying..."
                isConnected = false
                connectedDevice = nil
                bleManager.disconnect(from: device.id)
                // Re-enable screen sleep when disconnected
                UIApplication.shared.isIdleTimerDisabled = false
                print("[WORKOUT] Screen idle timer re-enabled")
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                checkConnectionStatus(device)
            }
        }
    }
    
    private func cleanup() {
        print("[WORKOUT] Cleaning up...")
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        bleManager.stopScanning()
        bleManager.disconnectAll()
        // Re-enable screen sleep when leaving workout view
        UIApplication.shared.isIdleTimerDisabled = false
        print("[WORKOUT] Screen idle timer re-enabled")
    }
}

// Extension to get string description of CBManagerState
extension CBManagerState {
    var stateDescription: String {
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
    WorkoutView()
}
