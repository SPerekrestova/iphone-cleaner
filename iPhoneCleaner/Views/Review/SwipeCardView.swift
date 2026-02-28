import SwiftUI

struct SwipeCardView: View {
    let image: UIImage?
    let category: IssueCategory
    let confidence: Double
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0

    private var swipeThreshold: CGFloat { 120 }

    private var swipeColor: Color {
        if offset.width > 50 { return .green.opacity(0.3) }
        if offset.width < -50 { return .red.opacity(0.3) }
        return .clear
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)

            VStack(spacing: 12) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                HStack {
                    Label(category.displayName, systemImage: category.systemImage)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple.opacity(0.2))
                        .clipShape(Capsule())
                        .accessibilityIdentifier("swipeCardCategory")

                    Spacer()

                    Text("\(Int(confidence * 100))% match")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("confidenceText")
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            // Swipe overlay indicators
            HStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)
                    .opacity(offset.width < -50 ? min(Double(-offset.width - 50) / 100.0, 1.0) : 0)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                    .opacity(offset.width > 50 ? min(Double(offset.width - 50) / 100.0, 1.0) : 0)
            }
            .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: 500)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(swipeColor, lineWidth: 3)
        )
        .offset(offset)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { value in
                    offset = value.translation
                    rotation = Double(value.translation.width / 20)
                }
                .onEnded { value in
                    if value.translation.width < -swipeThreshold {
                        withAnimation(.easeOut(duration: 0.3)) {
                            offset = CGSize(width: -500, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeLeft()
                            offset = .zero
                            rotation = 0
                        }
                    } else if value.translation.width > swipeThreshold {
                        withAnimation(.easeOut(duration: 0.3)) {
                            offset = CGSize(width: 500, height: 0)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeRight()
                            offset = .zero
                            rotation = 0
                        }
                    } else {
                        withAnimation(.spring()) {
                            offset = .zero
                            rotation = 0
                        }
                    }
                }
        )
    }
}
