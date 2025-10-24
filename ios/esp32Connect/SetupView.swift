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
    @Environment(\.dismiss) var dismiss
    @StateObject private var screenTimeManager = ScreenTimeManager.shared
    @State private var showingAppPicker = false
    
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
                        ForEach($workoutSettings.exercises) { $exercise in
                            ExerciseConfigRow(exercise: $exercise)
                        }
                        
                        // Screen Time Controls Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Screen Time Controls")
                                .font(.headline)
                                .fontWeight(.bold)
                                .padding(.top, 10)
                            
                            Text("Block selected apps from midnight until you complete your workout")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Toggle for enabling screen time
                            Toggle(isOn: $workoutSettings.screenTimeEnabled) {
                                Text("Enable App Blocking")
                                    .font(.body)
                            }
                            .tint(.blue)
                            .onChange(of: workoutSettings.screenTimeEnabled) { enabled in
                                if enabled && !screenTimeManager.isAuthorized {
                                    Task {
                                        await screenTimeManager.requestAuthorization()
                                        if !screenTimeManager.isAuthorized {
                                            workoutSettings.screenTimeEnabled = false
                                        }
                                    }
                                }
                            }
                            
                            // Show app selection button when enabled
                            if workoutSettings.screenTimeEnabled {
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
                                    
                                    // Show selected apps count
                                    if !screenTimeManager.selectedApps.applicationTokens.isEmpty || 
                                       !screenTimeManager.selectedApps.categoryTokens.isEmpty {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Apps selected for blocking")
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                        }
                                    }
                                } else {
                                    Text("⚠️ Screen Time authorization required")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
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
        }
    }
}

struct ExerciseConfigRow: View {
    @Binding var exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.name)
                .font(.headline)
                .fontWeight(.bold)
            
            HStack(spacing: 15) {
                Text("Target Reps:")
                    .font(.body)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Decrease button
                Button(action: {
                    if exercise.targetReps > 1 {
                        exercise.targetReps -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(exercise.targetReps > 1 ? .blue : .gray)
                }
                .disabled(exercise.targetReps <= 1)
                
                // Rep count display
                Text("\(exercise.targetReps)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .frame(minWidth: 50)
                
                // Increase button
                Button(action: {
                    if exercise.targetReps < 50 {
                        exercise.targetReps += 1
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(exercise.targetReps < 50 ? .blue : .gray)
                }
                .disabled(exercise.targetReps >= 50)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    SetupView(workoutSettings: .constant(WorkoutSettings()))
}
