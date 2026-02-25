import SwiftUI

struct DeletionSuccessView: View {
    let photosDeleted: Int
    let bytesFreed: Int64
    let onDismiss: () -> Void

    @State private var showCheckmark = false
    @State private var showText = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)

            VStack(spacing: 8) {
                Text("\(photosDeleted) photos deleted")
                    .font(.title2.bold())

                Text("\(ByteCountFormatter.string(fromByteCount: bytesFreed, countStyle: .file)) freed")
                    .font(.title3)
                    .foregroundStyle(.purple)
            }
            .opacity(showText ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.4), value: showText)

            Text("Photos moved to Recently Deleted.\nRecoverable for 30 days.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showText ? 1 : 0)

            Spacer()

            Button("Done") {
                onDismiss()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.accentGradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(.systemBackground))
        .onAppear {
            showCheckmark = true
            showText = true
        }
    }
}
