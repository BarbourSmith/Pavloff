//
//  EventLogView.swift
//  esp32Connect
//
//  View for displaying the event log for debugging midnight blocking
//

import SwiftUI

struct EventLogView: View {
    @State private var events: [LogEvent] = []
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                if events.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Events Logged")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("Events will appear here as they occur")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(events) { event in
                            EventRowView(event: event)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Event Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingClearConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .disabled(events.isEmpty)
                }
            }
            .alert("Clear Event Log?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    EventLogManager.shared.clearEvents()
                    loadEvents()
                }
            } message: {
                Text("This will delete all logged events.")
            }
        }
        .onAppear {
            loadEvents()
        }
    }
    
    private func loadEvents() {
        events = EventLogManager.shared.getEvents().reversed()
    }
}

struct EventRowView: View {
    let event: LogEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(event.eventType.rawValue)
                    .font(.headline)
                    .foregroundColor(eventTypeColor)
                
                Spacer()
                
                Text(event.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Text(event.message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(event.source)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private var eventTypeColor: Color {
        switch event.eventType {
        case .midnightTrigger:
            return .blue
        case .workoutCompleted:
            return .green
        case .appsBlocked:
            return .red
        case .appsUnblocked:
            return .green
        case .appLaunched:
            return .blue
        case .extensionError:
            return .red
        case .info:
            return .gray
        }
    }
}

#Preview {
    EventLogView()
}
