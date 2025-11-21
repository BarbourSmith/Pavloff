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
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var newExerciseReps = 10
    
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
                    onAdd: {
                        addExercise()
                    },
                    onCancel: {
                        showingAddExercise = false
                        newExerciseName = ""
                        newExerciseReps = 10
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
            showingAddExercise = false
            newExerciseName = ""
            newExerciseReps = 10
            return
        }
        
        let exercise = Exercise(name: newExerciseName.trimmingCharacters(in: .whitespaces), targetReps: newExerciseReps)
        workoutSettings.exercises.append(exercise)
        workoutSettings.save()
        
        showingAddExercise = false
        newExerciseName = ""
        newExerciseReps = 10
    }
    
    private func deleteExercise(_ exercise: Exercise) {
        // Prevent deleting if it's the last exercise
        guard workoutSettings.exercises.count > 1 else {
            return
        }
        
        workoutSettings.exercises.removeAll { $0.id == exercise.id }
        workoutSettings.save()
    }
}

struct ExerciseConfigRow: View {
    @Binding var exercise: Exercise
    var onDelete: () -> Void
    
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

struct AddExerciseSheet: View {
    @Binding var exerciseName: String
    @Binding var exerciseReps: Int
    var onAdd: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Exercise Name")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    TextField("e.g., Squats, Push-ups", text: $exerciseName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Target Reps")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Button(action: {
                            if exerciseReps > 1 {
                                exerciseReps -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(exerciseReps > 1 ? .blue : .gray)
                        }
                        .disabled(exerciseReps <= 1)
                        
                        Text("\(exerciseReps)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(minWidth: 50)
                        
                        Button(action: {
                            if exerciseReps < 50 {
                                exerciseReps += 1
                            }
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(exerciseReps < 50 ? .blue : .gray)
                        }
                        .disabled(exerciseReps >= 50)
                    }
                    .padding(.horizontal)
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
    SetupView(workoutSettings: .constant(WorkoutSettings()))
}
