//
//  HoldToConfirmButton.swift
//  esp32Connect
//
//  A button that requires holding for a specified duration to confirm an action
//

import SwiftUI

struct HoldToConfirmButton: View {
    let title: String
    let holdDuration: TimeInterval
    let action: () -> Void
    let backgroundColor: Color
    let foregroundColor: Color
    let icon: String?
    
    @State private var isHolding = false
    @State private var holdProgress: Double = 0.0
    @State private var timer: Timer?
    @State private var elapsedTime: TimeInterval = 0.0
    
    private let updateInterval: TimeInterval = 0.5 // Update twice per second for smooth countdown with minimal overhead
    
    init(
        title: String,
        holdDuration: TimeInterval = 30.0,
        backgroundColor: Color = .red,
        foregroundColor: Color = .white,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.holdDuration = holdDuration
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: {}) { // Empty action - we handle via gestures
            ZStack {
                // Background progress bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(backgroundColor.opacity(0.3))
                        .frame(width: geometry.size.width)
                    
                    Rectangle()
                        .fill(backgroundColor)
                        .frame(width: geometry.size.width * holdProgress)
                        .animation(.linear(duration: updateInterval), value: holdProgress)
                }
                
                // Button content
                HStack {
                    if let iconName = icon {
                        Image(systemName: iconName)
                    }
                    
                    if isHolding {
                        let remainingSeconds = Int(ceil(holdDuration - elapsedTime))
                        Text("\(title) (\(remainingSeconds)s)")
                    } else {
                        Text(title)
                    }
                }
                .fontWeight(.semibold)
                .foregroundColor(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(backgroundColor, lineWidth: isHolding ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHolding {
                        startHolding()
                    }
                }
                .onEnded { _ in
                    stopHolding()
                }
        )
    }
    
    private func startHolding() {
        isHolding = true
        elapsedTime = 0.0
        holdProgress = 0.0
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime += self.updateInterval
            self.holdProgress = min(self.elapsedTime / self.holdDuration, 1.0)
            
            if self.elapsedTime >= self.holdDuration {
                self.completeHold()
            }
        }
    }
    
    private func stopHolding() {
        isHolding = false
        elapsedTime = 0.0
        holdProgress = 0.0
        timer?.invalidate()
        timer = nil
    }
    
    private func completeHold() {
        stopHolding()
        action()
    }
}

#Preview {
    VStack(spacing: 20) {
        HoldToConfirmButton(
            title: "Hold to Clear",
            holdDuration: 3.0, // Short duration for preview
            backgroundColor: .red,
            foregroundColor: .white,
            icon: "xmark.circle.fill"
        ) {
            print("Action completed!")
        }
        .padding()
        
        HoldToConfirmButton(
            title: "Hold to Confirm",
            holdDuration: 5.0,
            backgroundColor: .orange,
            foregroundColor: .white,
            icon: "checkmark.circle.fill"
        ) {
            print("Confirmed!")
        }
        .padding()
    }
}
