import SwiftUI

struct ScanningView: View {
    let scanEngine: PhotoScanEngine
    let onComplete: (ScanResult) -> Void

    @State private var hasStarted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: scanEngine.progress.fraction)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: scanEngine.progress.fraction)

                VStack(spacing: 4) {
                    Text(scanEngine.progress.percentFormatted)
                        .font(.largeTitle.bold())
                    Text("\(scanEngine.progress.processed) of \(scanEngine.progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Analyzing your photos...")
                .font(.title3)
                .foregroundStyle(.secondary)

            // Live category counts
            VStack(spacing: 8) {
                ForEach(IssueCategory.allCases, id: \.self) { category in
                    let count = scanEngine.progress.categoryCounts[category] ?? 0
                    HStack {
                        Image(systemName: category.systemImage)
                            .frame(width: 24)
                        Text(category.displayName)
                        Spacer()
                        Text("\(count)")
                            .bold()
                    }
                    .foregroundStyle(count > 0 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            do {
                let issues = try await scanEngine.scan()
                let result = ScanResult(
                    totalPhotosScanned: scanEngine.progress.total,
                    duplicatesFound: issues.filter { $0.category == .duplicate }.count,
                    similarFound: issues.filter { $0.category == .similar }.count,
                    blurryFound: issues.filter { $0.category == .blurry }.count,
                    screenshotsFound: issues.filter { $0.category == .screenshot }.count,
                    totalSizeReclaimable: issues.reduce(0) { $0 + $1.fileSize }
                )
                onComplete(result)
            } catch {
                dismiss()
            }
        }
    }
}
