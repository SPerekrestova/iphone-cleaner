import SwiftUI
import SwiftData

@main
struct iPhoneCleanerApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [PhotoIssue.self, ScanResult.self])
    }
}
