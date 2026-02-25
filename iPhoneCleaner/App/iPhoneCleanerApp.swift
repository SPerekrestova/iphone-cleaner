import SwiftUI
import SwiftData

@main
struct iPhoneCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [PhotoIssue.self, ScanResult.self])
    }
}
