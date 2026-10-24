import SwiftUI
import DongKeCore

struct DoseProposalCard: View {
    let proposal: PlanProposal
    let onAccept: () -> Void
    let onReject: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: Icons.increment)
                    .font(Typography.capsLabel)
                Text("上一阶")
                    .font(Typography.capsLabel)
            }
            .foregroundStyle(Theme.accent(for: colorScheme))

            VStack(alignment: .leading, spacing: 4) {
                ForEach(proposal.changes, id: \.itemId) { change in
                    Text(change.summary)
                        .font(Typography.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }

            Text(proposal.reason)
                .font(Typography.meta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("就这样")
                        .font(Typography.buttonLabel)
                        .foregroundStyle(Theme.callToActionInk(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Theme.accent(for: colorScheme), in: Capsule())
                }
                .buttonStyle(PressableGlassStyle())

                Button(action: onReject) {
                    Text("先不用")
                        .font(Typography.buttonLabel)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(PressableGlassStyle())
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.glassCard, style: .continuous)
                .fill(Theme.accent(for: colorScheme).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.glassCard, style: .continuous)
                .stroke(Theme.accent(for: colorScheme).opacity(0.35), lineWidth: 1)
        )
    }
}
