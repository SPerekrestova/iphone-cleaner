import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            Form {
                Section("Detection Sensitivity") {
                    VStack(alignment: .leading) {
                        Text("Blur Threshold: \(Int(appState.scanSettings.blurThreshold * 100))%")
                        Slider(value: $appState.scanSettings.blurThreshold, in: 0.1...0.8, step: 0.05)
                            .tint(.purple)
                        Text("Lower = more photos flagged as blurry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Similarity Threshold: \(Int(Double(appState.scanSettings.similarThreshold) * 100))%")
                        Slider(value: Binding(
                            get: { Double(appState.scanSettings.similarThreshold) },
                            set: { appState.scanSettings.similarThreshold = Float($0) }
                        ), in: 0.5...0.99, step: 0.05)
                            .tint(.purple)
                        Text("Lower = more photos flagged as similar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Privacy") {
                    Label("All processing happens on your device", systemImage: "lock.shield")
                    Label("No data is sent to any server", systemImage: "wifi.slash")
                    Label("No account required", systemImage: "person.slash")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
