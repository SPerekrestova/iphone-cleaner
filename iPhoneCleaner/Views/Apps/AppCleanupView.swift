import SwiftUI

struct AppCleanupView: View {
    @State private var viewModel = AppCleanupViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.apps.isEmpty {
                    ContentUnavailableView(
                        "No App Data",
                        systemImage: "square.grid.2x2",
                        description: Text("App usage data requires Screen Time access. Enable it in Settings > Screen Time.")
                    )
                } else {
                    List(viewModel.apps) { app in
                        AppRow(app: app)
                    }
                }
            }
            .navigationTitle("App Cleanup")
            .toolbar {
                if !viewModel.apps.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await viewModel.generateSuggestions() }
                        } label: {
                            if viewModel.isLoadingSuggestions {
                                ProgressView()
                            } else {
                                Label("Get AI Tips", systemImage: "sparkles")
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadApps()
            }
        }
    }
}

private struct AppRow: View {
    let app: AppInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.purple.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.purple)
                    }

                VStack(alignment: .leading) {
                    Text(app.name)
                        .font(.headline)
                    HStack {
                        Text(app.sizeFormatted)
                        if let days = app.daysSinceLastUsed {
                            Text("Last used \(days)d ago")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let suggestion = app.aiSuggestion {
                Text(suggestion)
                    .font(.caption)
                    .padding(8)
                    .background(.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}
