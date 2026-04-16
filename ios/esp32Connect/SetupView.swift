//
//  SetupView.swift
//  esp32Connect
//
//  Setup screen for configuring workout exercises and target reps
//

import SwiftUI
import FamilyControls

struct SetupView: View {
    @Binding var workoutSettings: WorkoutSettings
    var batteryData: BatteryData? = nil
    @Environment(\.dismiss) var dismiss
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showingAppPicker = false
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseReps = 10
    @State private var newExerciseDuration = 60
    @State private var newExerciseType: ActivityType = .reps
    
    // Exercise rep limits
    private let minExerciseReps = 1
    private let maxExerciseReps = 50
    private let defaultExerciseReps = 10
    private let defaultDuration = 60
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Text("Workout Setup")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Set your target reps for each exercise")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white)
                
                // Exercise list
                ScrollView {
                    VStack(spacing: 15) {
                        // Add Exercise Button
                        Button(action: {
                            showingAddExercise = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add New Exercise")
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                        
                        ForEach($workoutSettings.exercises) { $exercise in
                            ExerciseConfigRow(exercise: $exercise, onDelete: {
                                deleteExercise(exercise)
                            })
                        }
                        
                        // Battery Status Section
                        if let battery = batteryData, battery.voltage > 0 {
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Sensor Battery")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .padding(.top, 10)

                                HStack(spacing: 12) {
                                    // Battery icon
                                    Image(systemName: batteryIconName(battery.percentage))
                                        .font(.system(size: 28))
                                        .foregroundColor(batteryColor(battery.percentage))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(battery.formattedPercentage)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(batteryColor(battery.percentage))

                                        Text(battery.formattedVoltage)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    // Battery level bar
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 12)

                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(batteryColor(battery.percentage))
                                                .frame(width: max(0, CGFloat(battery.percentage) / 100.0 * geometry.size.width), height: 12)
                                        }
                                    }
                                    .frame(height: 12)
                                    .frame(maxWidth: 120)
                                }

                                if battery.isLow {
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(battery.isCritical ? "Battery critically low. Please charge soon." : "Battery is getting low. Consider charging.")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }

                        // Sensitivity Settings Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Sensitivity Settings")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.top, 10)
                            
                            Text("Adjust detection sensitivity for rep counting and vibration tracking")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Rep Detection Sensitivity
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Rep Detection Sensitivity")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(sensitivityLabel(workoutSettings.repSensitivity))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                HStack(spacing: 12) {
                                    Text("Low")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Slider(value: $workoutSettings.repSensitivity, in: 0...1, step: 0.1)
                                        .accentColor(.blue)
                                    
                                    Text("High")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Text("Higher sensitivity detects smaller movements for rep counting")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.top, 2)
                            }
                            
                            Divider()
                                .padding(.vertical, 5)
                            
                            // Vibration Detection Sensitivity
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Vibration Detection Sensitivity")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(sensitivityLabel(workoutSettings.vibrationSensitivity))
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                
                                HStack(spacing: 12) {
                                    Text("Low")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Slider(value: $workoutSettings.vibrationSensitivity, in: 0...1, step: 0.1)
                                        .accentColor(.orange)
                                    
                                    Text("High")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Text("Higher sensitivity detects smaller vibrations for duration tracking")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.top, 2)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                        // Screen Time Controls Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Screen Time Controls")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.top, 10)
                            
                            Text("Block selected apps until you complete your workout")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Show app selection button
                            if screenTimeManager.isAuthorized {
                                Button(action: {
                                    showingAppPicker = true
                                }) {
                                    HStack {
                                        Image(systemName: "hand.raised.fill")
                                        Text("Select Apps to Block")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                                }
                                
                                // Show selected apps count and clear button
                                if !screenTimeManager.selectedApps.applicationTokens.isEmpty || 
                                   !screenTimeManager.selectedApps.categoryTokens.isEmpty ||
                                   screenTimeManager.hasAppsSelected {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Apps selected for blocking")
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                        Spacer()
                                    }
                                    
                                    // Clear selection button - requires 30 second hold
                                    HoldToConfirmButton(
                                        title: "Hold to Clear Selection",
                                        holdDuration: 30.0,
                                        backgroundColor: Color.red.opacity(0.15),
                                        foregroundColor: .red,
                                        icon: "xmark.circle.fill"
                                    ) {
                                        screenTimeManager.clearSelection()
                                    }
                                    .padding(.horizontal, 0)
                                }
                            } else {
                                Text("⚠️ Screen Time authorization required")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                                
                                Button(action: {
                                    Task {
                                        await screenTimeManager.requestAuthorization()
                                    }
                                }) {
                                    Text("Request Authorization")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    .padding()
                }
                .background(Color(red: 0.97, green: 0.98, blue: 0.98))
                
                // Start workout button
                Button(action: {
                    dismiss()
                }) {
                    Text("Start Workout")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.white)
            }
            .navigationBarTitleDisplayMode(.inline)
            .familyActivityPicker(isPresented: $showingAppPicker, selection: $screenTimeManager.selectedApps)
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet(
                    exerciseName: $newExerciseName,
                    exerciseReps: $newExerciseReps,
                    exerciseDuration: $newExerciseDuration,
                    exerciseType: $newExerciseType,
                    onAdd: {
                        addExercise()
                    },
                    onCancel: {
                        resetExerciseForm()
                    }
                )
            }
            .onChange(of: showingAppPicker) { isPresented in
                // When app picker is dismissed and apps are selected, apply shields immediately
                if !isPresented && screenTimeManager.isAuthorized {
                    if !screenTimeManager.selectedApps.applicationTokens.isEmpty || !screenTimeManager.selectedApps.categoryTokens.isEmpty {
                        screenTimeManager.enableAppBlocking()
                    }
                }
            }
            .onChange(of: workoutSettings.exercises) { _ in
                // Save settings whenever exercises change
                workoutSettings.save()
            }
            .onChange(of: workoutSettings.repSensitivity) { _ in
                // Save settings whenever rep sensitivity changes
                workoutSettings.save()
            }
            .onChange(of: workoutSettings.vibrationSensitivity) { _ in
                // Save settings whenever vibration sensitivity changes
                workoutSettings.save()
            }
            .onAppear {
                // Request authorization on appear if not already authorized
                if !screenTimeManager.isAuthorized {
                    Task {
                        await screenTimeManager.requestAuthorization()
                    }
                }
            }
        }
    }
    
    private func addExercise() {
        guard !newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty else {
            resetExerciseForm()
            return
        }
        
        let exercise = Exercise(
            name: newExerciseName.trimmingCharacters(in: .whitespaces),
            targetReps: newExerciseReps,
            targetDuration: newExerciseDuration,
            activityType: newExerciseType
        )
        workoutSettings.exercises.append(exercise)
        workoutSettings.save()
        
        resetExerciseForm()
    }
    
    private func resetExerciseForm() {
        showingAddExercise = false
        newExerciseName = ""
        newExerciseReps = defaultExerciseReps
        newExerciseDuration = defaultDuration
        newExerciseType = .reps
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        // Prevent deleting if it's the last exercise
        guard workoutSettings.exercises.count > 1 else {
            return
        }
        
        workoutSettings.exercises.removeAll { $0.id == exercise.id }
        workoutSettings.save()
    }
    
    private func batteryIconName(_ percentage: Int) -> String {
        switch percentage {
        case 76...100: return "battery.100"
        case 51...75: return "battery.75"
        case 26...50: return "battery.50"
        case 11...25: return "battery.25"
        default: return "battery.0"
        }
    }

    private func batteryColor(_ percentage: Int) -> Color {
        switch percentage {
        case 51...100: return .green
        case 21...50: return .yellow
        case 11...20: return .orange
        default: return .red
        }
    }

    private func sensitivityLabel(_ value: Double) -> String {
        if value < 0.3 {
            return "Low"
        } else if value < 0.7 {
            return "Medium"
        } else {
            return "High"
        }
    }
}

struct ExerciseConfigRow: View {
    @Binding var exercise: Exercise
    var onDelete: () -> Void
    
    // Exercise rep limits (matching SetupView constants)
    private let minExerciseReps = 1
    private let maxExerciseReps = 50
    private let minDuration = 10 // seconds
    private let maxDuration = 600 // 10 minutes in seconds
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .foregroundColor(.red)
                }
            }
            
            // Activity Type Picker
            Picker("Activity Type", selection: $exercise.activityType) {
                Text("Reps").tag(ActivityType.reps)
                Text("Duration").tag(ActivityType.duration)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 5)
            
            if exercise.activityType == .reps {
                // Reps control
                HStack(spacing: 15) {
                    Text("Target Reps:")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Decrease button
                    Button(action: {
                        if exercise.targetReps > minExerciseReps {
                            exercise.targetReps -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(exercise.targetReps > minExerciseReps ? .blue : .gray)
                    }
                    .disabled(exercise.targetReps <= minExerciseReps)
                    
                    // Rep count display
                    Text("\(exercise.targetReps)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .frame(minWidth: 50)
                    
                    // Increase button
                    Button(action: {
                        if exercise.targetReps < maxExerciseReps {
                            exercise.targetReps += 1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(exercise.targetReps < maxExerciseReps ? .blue : .gray)
                    }
                    .disabled(exercise.targetReps >= maxExerciseReps)
                }
            } else {
                // Duration control
                HStack(spacing: 15) {
                    Text("Target Duration:")
                        .font(.body)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    // Decrease button
                    Button(action: {
                        if exercise.targetDuration > minDuration {
                            exercise.targetDuration -= 10
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(exercise.targetDuration > minDuration ? .blue : .gray)
                    }
                    .disabled(exercise.targetDuration <= minDuration)
                    
                    // Duration display
                    Text(exercise.targetDuration.formatAsDuration())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .frame(minWidth: 70)
                    
                    // Increase button
                    Button(action: {
                        if exercise.targetDuration < maxDuration {
                            exercise.targetDuration += 10
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(exercise.targetDuration < maxDuration ? .blue : .gray)
                    }
                    .disabled(exercise.targetDuration >= maxDuration)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct AddExerciseSheet: View {
    @Binding var exerciseName: String
    @Binding var exerciseReps: Int
    @Binding var exerciseDuration: Int
    @Binding var exerciseType: ActivityType
    var onAdd: () -> Void
    var onCancel: () -> Void
    
    // Exercise limits (matching SetupView constants)
    private let minExerciseReps = 1
    private let maxExerciseReps = 50
    private let minDuration = 10
    private let maxDuration = 600
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercise Name")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    TextField("e.g., Squats, Treadmill", text: $exerciseName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Activity Type")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Picker("Activity Type", selection: $exerciseType) {
                        Text("Reps").tag(ActivityType.reps)
                        Text("Duration").tag(ActivityType.duration)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                }
                
                if exerciseType == .reps {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target Reps")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Button(action: {
                                if exerciseReps > minExerciseReps {
                                    exerciseReps -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(exerciseReps > minExerciseReps ? .blue : .gray)
                            }
                            .disabled(exerciseReps <= minExerciseReps)
                            
                            Text("\(exerciseReps)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(minWidth: 50)
                            
                            Button(action: {
                                if exerciseReps < maxExerciseReps {
                                    exerciseReps += 1
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(exerciseReps < maxExerciseReps ? .blue : .gray)
                            }
                            .disabled(exerciseReps >= maxExerciseReps)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Target Duration")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        HStack {
                            Button(action: {
                                if exerciseDuration > minDuration {
                                    exerciseDuration -= 10
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(exerciseDuration > minDuration ? .blue : .gray)
                            }
                            .disabled(exerciseDuration <= minDuration)
                            
                            Text(exerciseDuration.formatAsDuration())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(minWidth: 70)
                            
                            Button(action: {
                                if exerciseDuration < maxDuration {
                                    exerciseDuration += 10
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(exerciseDuration < maxDuration ? .blue : .gray)
                            }
                            .disabled(exerciseDuration >= maxDuration)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd()
                    }
                    .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    SetupView(workoutSettings: .constant(WorkoutSettings()), batteryData: BatteryData(voltage: 3.85, percentage: 71))
}
