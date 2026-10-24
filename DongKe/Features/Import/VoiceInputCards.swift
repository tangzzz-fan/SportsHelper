import SwiftUI
import DongKeCore

struct VoiceInputOnlineCard: View {
    var onAccept: () -> Void
    var onDecline: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(VoiceInputCopy.onlineTitle)
                .font(Typography.cardTitle)
            Text(VoiceInputCopy.onlineBody)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Text(VoiceInputCopy.onlineAccept)
                        .font(Typography.meta.weight(.semibold))
                        .foregroundStyle(Theme.callToActionInk(for: colorScheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            Theme.accent(for: colorScheme),
                            in: Capsule(style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Import.voiceOnlineAccept)

                Button(action: onDecline) {
                    Text(VoiceInputCopy.onlineDecline)
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Import.voiceOnlineDecline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        )
    }
}

struct VoiceInputFailureCard: View {
    var failure: VoiceInputFailure
    var onRetry: () -> Void
    var onSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(failure.message)
                .font(.caption)
                .foregroundStyle(Theme.danger(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if failure.opensSettings {
                    Button(action: onSettings) {
                        Text(VoiceInputCopy.openSettings)
                            .font(Typography.meta.weight(.semibold))
                            .foregroundStyle(Theme.accent(for: colorScheme))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11y.Import.voiceSettings)
                }

                Button(action: onRetry) {
                    Text("再试一次")
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Import.voiceStart)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
