import SwiftUI
import UIKit
import DongKeCore

struct VoiceInputBar: View {
    @Binding var text: String

    @State private var machine: VoiceInputMachine?

    var body: some View {
        Group {
            if let machine {
                VoiceInputPanel(machine: machine, text: $text)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .task {
            if machine == nil {
                machine = VoiceInputService.makeMachine()
            }
        }
    }
}

private struct VoiceInputPanel: View {
    let machine: VoiceInputMachine
    @Binding var text: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var ticker: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch machine.phase {
            case .idle:
                startRow
            case .requestingAuthorization:
                preparingRow
            case .listening:
                listeningBlock
            case .awaitingOnlineConsent:
                VoiceInputOnlineCard(
                    onAccept: { machine.allowOnline() },
                    onDecline: { machine.declineOnline() }
                )
            case .finished:
                Color.clear.frame(height: 0)
            case .failed(let failure):
                VoiceInputFailureCard(
                    failure: failure,
                    onRetry: { machine.start() },
                    onSettings: openSettings
                )
            }
        }
        .onChange(of: machine.phase) { _, phase in
            switch phase {
            case .finished(let transcript):
                text = transcript
                machine.reset()
            case .listening:
                startTicker()
            default:
                stopTicker()
            }
        }
        .onDisappear {
            stopTicker()
            machine.cancel()
        }
    }

    private var startRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                machine.start()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: Icons.mic)
                        .font(Typography.meta)
                    Text(VoiceInputCopy.actionStart)
                        .font(Typography.meta.weight(.medium))
                }
                .foregroundStyle(Theme.accent(for: colorScheme))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11y.Import.voiceStart)

            Text(VoiceInputCopy.privacy)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(A11y.Import.voiceHint)
        }
    }

    private var preparingRow: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("正在准备麦克风…")
                .font(Typography.meta)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
    }

    private var listeningBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Theme.danger(for: colorScheme))
                    .frame(width: 8, height: 8)
                Text("正在听…还能说 \(machine.remainingSeconds) 秒")
                    .font(Typography.meta)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }

            if machine.transcript.isEmpty == false {
                Text(machine.transcript)
                    .font(Typography.secondary)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button {
                    machine.stop()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: Icons.micStop)
                            .font(Typography.meta)
                        Text(VoiceInputCopy.actionStop)
                            .font(Typography.meta.weight(.semibold))
                    }
                    .foregroundStyle(Theme.callToActionInk(for: colorScheme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Theme.accent(for: colorScheme),
                        in: Capsule(style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Import.voiceStop)

                Button {
                    machine.cancel()
                } label: {
                    Text(VoiceInputCopy.actionCancel)
                        .font(Typography.meta)
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11y.Import.voiceCancel)
            }

            if machine.didHitLengthLimit {
                Text(machine.capHint)
                    .font(.caption2)
                    .foregroundStyle(Theme.danger(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func startTicker() {
        stopTicker()
        ticker = Task { @MainActor in
            while Task.isCancelled == false, machine.phase.isListening {
                machine.tick()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
