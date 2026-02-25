import SwiftUI

struct StorageRingView: View {
    let fraction: Double
    let usedText: String
    let totalText: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(
                        colors: [.purple, .blue, .purple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: fraction)

            VStack(spacing: 4) {
                Text(usedText)
                    .font(.title2.bold())
                Text("of \(totalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 150, height: 150)
    }
}
