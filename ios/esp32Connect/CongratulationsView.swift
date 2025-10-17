//
//  CongratulationsView.swift
//  esp32Connect
//
//  Congratulations screen shown when all exercises are completed
//

import SwiftUI

struct CongratulationsView: View {
    let workoutSettings: WorkoutSettings
    let onRestart: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Celebration icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 150, height: 150)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
            }
            
            // Congratulations text
            VStack(spacing: 12) {
                Text("Congratulations!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("You've completed your workout!")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Workout summary
            VStack(alignment: .leading, spacing: 15) {
                Text("Workout Summary")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ForEach(workoutSettings.exercises) { exercise in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text(exercise.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Text("\(exercise.targetReps) reps")
                            .font(.body)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    onRestart()
                    dismiss()
                }) {
                    Text("Start New Workout")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
        .background(Color.white)
    }
}

#Preview {
    CongratulationsView(
        workoutSettings: WorkoutSettings(),
        onRestart: {}
    )
}
