import SwiftUI
import DongKeCore

struct MicroDoseView: View {
    let dose: MicroDose

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(MicroDoseStore.self) private var store

    @State private var setIndex = 1
    @State private var isResting = false
    @State private var deadline = Date()
    @State private var now = Date()
    @State private var finished = false
    @State private var started = false
    @State private var elapsed = 0

    private var remaining: Int {
        max(0, Int(deadline.timeIntervalSince(now).rounded(.up)))
    }

    private var timeText: String {
        String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: Icons.close)
                        .font(Typography.body)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            if finished {
                finishedBody
            } else {
                activeBody
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            guard started == false else { return }
            started = true
            start(seconds: dose.seconds, resting: false)
            LocalCounters.shared.increment(.microDoseStarted)
        }
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
            advanceIfNeeded()
        }
    }

    private var activeBody: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Text(dose.name)
                .font(Typography.buttonLabel)
            ExerciseFigureView(catalogId: dose.catalogId, figureSize: CGSize(width: 180, height: 212), autoPlays: true)
            Text(isResting ? "组间休息" : "第 \(setIndex) 组 / 共 \(dose.sets) 组")
                .font(Typography.meta)
                .foregroundStyle(.secondary)
            Text(timeText)
                .font(Typography.timer)
                .monospacedDigit()
                .foregroundStyle(Theme.accent(for: colorScheme))
            Spacer(minLength: 0)
            Button {
                advance()
            } label: {
                Text(isResting ? "跳过休息" : "做完这组")
                    .font(Typography.buttonLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(PressableGlassStyle())
            .glassSurface(radius: Theme.Radius.card)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private var finishedBody: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("记下了。")
                .font(Typography.pageTitle)
            Text("这三分钟不算一次训练。")
                .font(Typography.body)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("好")
                    .font(Typography.buttonLabel)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(PressableGlassStyle())
            .glassSurface(radius: Theme.Radius.card)
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private func start(seconds: Int, resting: Bool) {
        isResting = resting
        deadline = Date().addingTimeInterval(Double(seconds))
    }

    private func advanceIfNeeded() {
        guard finished == false, remaining == 0 else { return }
        advance()
    }

    private func advance() {
        if isResting {
            start(seconds: dose.seconds, resting: false)
            return
        }
        elapsed += dose.seconds
        guard setIndex < dose.sets else {
            finish()
            return
        }
        setIndex += 1
        start(seconds: dose.restSec, resting: true)
    }

    private func finish() {
        finished = true
        store.log(dose, seconds: elapsed, completed: true)
        LocalCounters.shared.increment(.microDoseFinished)
    }
}
