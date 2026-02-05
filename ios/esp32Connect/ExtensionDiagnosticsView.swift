//
//  ExtensionDiagnosticsView.swift
//  esp32Connect
//
//  Diagnostic view to help debug extension issues
//

import SwiftUI
import DeviceActivity
import FamilyControls

struct ExtensionDiagnosticsView: View {
    @State private var diagnosticResults: [String] = []
    @State private var isRunning = false
    
    var body: some View {
        List {
            Section(header: Text("Extension Diagnostics")) {
                Button(action: runDiagnostics) {
                    HStack {
                        Text("Run Diagnostics")
                        Spacer()
                        if isRunning {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRunning)
                
                Button(action: testExtensionCodePath) {
                    Text("Test Extension Code (Manual)")
                }
                .disabled(isRunning)
            }
            
            if !diagnosticResults.isEmpty {
                Section(header: Text("Results")) {
                    ForEach(diagnosticResults, id: \.self) { result in
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle("Extension Diagnostics")
    }
    
    private func runDiagnostics() {
        isRunning = true
        diagnosticResults = []
        
        Task {
            await performDiagnostics()
            isRunning = false
        }
    }
    
    private func performDiagnostics() async {
        var results: [String] = []
        
        // Check 1: App Group access
        results.append("=== App Group Access ===")
        if let userDefaults = UserDefaults(suiteName: AppGroupConstants.appGroupIdentifier) {
            results.append("✅ App Group accessible")
            
            // Test write
            let testKey = "diagnosticTest"
            let testValue = Date().timeIntervalSince1970
            userDefaults.set(testValue, forKey: testKey)
            userDefaults.synchronize()
            
            // Test read
            if let readValue = userDefaults.value(forKey: testKey) as? TimeInterval, readValue == testValue {
                results.append("✅ App Group read/write working")
            } else {
                results.append("❌ App Group read failed")
            }
            
            // Clean up
            userDefaults.removeObject(forKey: testKey)
        } else {
            results.append("❌ Cannot access App Group")
            results.append("   Check entitlements")
        }
        
        // Check 2: Authorization
        results.append("\n=== Authorization ===")
        let authStatus = AuthorizationCenter.shared.authorizationStatus
        results.append("Status: \(authStatus == .approved ? "✅ Approved" : "❌ Not approved")")
        
        // Check 3: App selection
        results.append("\n=== App Selection ===")
        if let userDefaults = UserDefaults(suiteName: AppGroupConstants.appGroupIdentifier) {
            let hasSelection = userDefaults.bool(forKey: AppGroupConstants.Keys.hasAppSelection)
            results.append(hasSelection ? "✅ Apps selected" : "❌ No apps selected")
            
            if hasSelection {
                if let data = userDefaults.data(forKey: AppGroupConstants.Keys.savedAppSelection) {
                    results.append("✅ Selection data found (\(data.count) bytes)")
                    
                    do {
                        let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
                        results.append("   Apps: \(selection.applicationTokens.count)")
                        results.append("   Categories: \(selection.categoryTokens.count)")
                    } catch {
                        results.append("❌ Failed to decode selection")
                    }
                } else {
                    results.append("❌ Selection data not found")
                }
            }
        }
        
        // Check 4: DeviceActivity schedule
        results.append("\n=== DeviceActivity Schedule ===")
        results.append("⚠️ NOTE: iOS may not trigger")
        results.append("   schedules shorter than daily")
        results.append("   Hourly schedules are unreliable")
        
        // Check 5: Event Log
        results.append("\n=== Event Log ===")
        let events = EventLogManager.shared.getEvents()
        let extensionEvents = events.filter { $0.source == "Extension" }
        results.append("Total events: \(events.count)")
        results.append("Extension events: \(extensionEvents.count)")
        
        if extensionEvents.isEmpty {
            results.append("❌ No extension events found")
            results.append("   Extension has never run")
        } else {
            results.append("✅ Extension has run")
            if let lastEvent = extensionEvents.first {
                results.append("   Last: \(lastEvent.timestamp)")
            }
        }
        
        // Check 6: Recommendations
        results.append("\n=== Recommendations ===")
        if extensionEvents.isEmpty {
            results.append("1. Use 'Test Extension Code' button")
            results.append("   to verify extension logic works")
            results.append("2. For real testing, wait until")
            results.append("   midnight (daily schedule only)")
            results.append("3. Check Console.app for system logs")
            results.append("   (filter by 'DeviceActivityMonitor')")
        } else {
            results.append("✅ Extension appears to be working")
        }
        
        await MainActor.run {
            diagnosticResults = results
        }
        
        // Log diagnostics to event log
        EventLogManager.shared.log(
            source: "Diagnostics",
            type: .info,
            message: "Ran extension diagnostics - \(extensionEvents.count) extension events found"
        )
    }
    
    private func testExtensionCodePath() {
        // Manually trigger the extension logic to test it works
        EventLogManager.shared.log(
            source: "Diagnostics",
            type: .info,
            message: "Manual extension code test triggered"
        )
        
        // Simulate what the extension does
        guard let userDefaults = UserDefaults(suiteName: AppGroupConstants.appGroupIdentifier) else {
            EventLogManager.shared.log(
                source: "Diagnostics",
                type: .extensionError,
                message: "Failed to access App Group"
            )
            return
        }
        
        // Check workout completion
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastCompletion = userDefaults.object(forKey: AppGroupConstants.Keys.lastWorkoutCompletion) as? Date {
            let lastCompletionDay = calendar.startOfDay(for: lastCompletion)
            
            if calendar.isDate(lastCompletionDay, inSameDayAs: today) {
                EventLogManager.shared.log(
                    source: "Diagnostics",
                    type: .info,
                    message: "Test result: Workout completed today - would NOT block apps"
                )
            } else {
                EventLogManager.shared.log(
                    source: "Diagnostics",
                    type: .info,
                    message: "Test result: Workout NOT completed - would block apps"
                )
                
                // Try to reapply shields
                if let data = userDefaults.data(forKey: AppGroupConstants.Keys.savedAppSelection) {
                    do {
                        let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: data)
                        let appCount = selection.applicationTokens.count
                        let catCount = selection.categoryTokens.count
                        
                        EventLogManager.shared.log(
                            source: "Diagnostics",
                            type: .info,
                            message: "Test result: Would block \(appCount) apps and \(catCount) categories"
                        )
                    } catch {
                        EventLogManager.shared.log(
                            source: "Diagnostics",
                            type: .extensionError,
                            message: "Test failed: Cannot decode app selection"
                        )
                    }
                }
            }
        } else {
            EventLogManager.shared.log(
                source: "Diagnostics",
                type: .info,
                message: "Test result: No workout recorded - would block apps"
            )
        }
    }
}

#Preview {
    NavigationView {
        ExtensionDiagnosticsView()
    }
}
