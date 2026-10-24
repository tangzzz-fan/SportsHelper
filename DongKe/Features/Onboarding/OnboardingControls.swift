import SwiftUI
import DongKeCore


extension OnboardingView {
    func stepperCard(
        _ title: String,
        value: String,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(Typography.rowTitle)
            Spacer()
            HStack(spacing: 14) {
                Button(action: onDecrease) {
                    Image(systemName: Icons.decrement)
                        .font(Typography.meta.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.06), in: Circle())
                        .contentShape(Circle())
                }
                Text(value)
                    .font(Typography.buttonLabel)
                    .monospacedDigit()
                    .frame(minWidth: 66)
                Button(action: onIncrease) {
                    Image(systemName: Icons.increment)
                        .font(Typography.meta.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.06), in: Circle())
                        .contentShape(Circle())
                }
            }
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.card)
    }

    func chipRow<T: Hashable>(
        title: String,
        options: [(T, String)],
        isSelected: @escaping (T) -> Bool,
        onTap: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.0) { option in
                    Chip(label: option.1, selected: isSelected(option.0)) {
                        onTap(option.0)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.card)
    }

    func chipGrid<T: Hashable>(
        title: String,
        options: [(T, String)],
        isSelected: @escaping (T) -> Bool,
        onTap: @escaping (T) -> Void
    ) -> some View {
        chipRow(title: title, options: options, isSelected: isSelected, onTap: onTap)
    }
}

struct Chip: View {
    let label: String
    let selected: Bool
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Typography.secondary.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.accent(for: colorScheme) : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    selected ? Theme.halo(for: colorScheme) : Color.primary.opacity(0.05),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            selected ? Theme.accent(for: colorScheme).opacity(0.45) : Color.clear,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(PressableGlassStyle())
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: proposal.width ?? maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
