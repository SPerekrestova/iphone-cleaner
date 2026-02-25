import SwiftUI

struct CategoryCardView: View {
    let category: IssueCategory
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.systemImage)
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.subheadline.bold())
                    Text("\(count) found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
