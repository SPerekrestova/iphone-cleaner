import SwiftUI

struct SettingsView: View {
    @AppStorage("blurThreshold") private var blurThreshold: Double = 0.3
    @AppStorage("similarityThreshold") private var similarityThreshold: Double = 0.80

    var body: some View {
        NavigationStack {
            Form {
                Section("Detection Sensitivity") {
                    VStack(alignment: .leading) {
                        Text("Blur Threshold: \(Int(blurThreshold * 100))%")
                        Slider(value: $blurThreshold, in: 0.1...0.8, step: 0.05)
                            .tint(.purple)
                        Text("Lower = more photos flagged as blurry")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Similarity Threshold: \(Int(similarityThreshold * 100))%")
                        Slider(value: $similarityThreshold, in: 0.5...0.99, step: 0.05)
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
