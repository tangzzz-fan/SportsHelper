import SwiftUI
import DongKeCore

struct WorkoutView: View {
    @Bindable var session: WorkoutSession
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showSkipOptions = false
    @State private var showDowngradeOptions = false

    private var prescription: ExercisePrescription? { session.currentPrescription }

    private var doseText: String {
        guard let prescription else { return "" }
        let target = prescription.target
        let perSide = target.perSide ? " / 侧" : ""
        return "\(target.doseText)\(perSide) × \(prescription.sets) 组"
    }

    private var cueLines: [String] {
        guard let id = prescription?.catalogId else { return [] }
        guard let entry = ExerciseLibrary.all.first(where: { $0.id == id }) else { return [] }
        return Array(entry.cues.prefix(2))
    }

    private var halfTargetTitle: String {
        prescription?.target.type == .durationSec ? "减一半时间" : "减一半次数"
    }

    private var setCounterText: Text {
        Text("第 \(session.currentSetIndex) 组")
            .font(Typography.meta.weight(.semibold)) +
        Text(" / 共 \(session.currentSetTotal) 组")
            .font(Typography.meta)
            .foregroundColor(.secondary)
    }

    var body: some View {
        if session.showsSummary {
            WorkoutSummaryView(title: session.sessionTitle, recap: session.recap, onDone: onClose)
        } else {
            workoutBody
        }
    }

    private var workoutBody: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()

            if let prescription {
                ExerciseFigureView(catalogId: prescription.catalogId,
                                       figureSize: CGSize(width: 430, height: 500),
                                       showsHalo: false)
                    .opacity(0.06)
                    .offset(x: 140, y: -170)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                navBar

                Spacer(minLength: 0)

                if let prescription {
                    VStack(spacing: 18) {
                        ExerciseFigureView(catalogId: prescription.catalogId)

                        VStack(spacing: 2) {
                            Text(prescription.name)
                                .font(Typography.buttonLabel)
                            Text(doseText)
                                .font(Typography.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if cueLines.isEmpty == false {
                                VStack(spacing: 3) {
                                    ForEach(cueLines, id: \.self) { cue in
                                        Text(cue)
                                            .font(Typography.meta)
                                            .foregroundStyle(.tertiary)
                                            .multilineTextAlignment(.center)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.top, 8)
                                .accessibilityIdentifier(A11y.Workout.cues)
                            }
                        }
                    }
                } else {
                    finishedPlaceholder
                }

                Spacer(minLength: 0)

                if !session.isResting {
                    controlDock
                }
            }

            if session.isResting {
                RestSheetView(session: session)
                    .transition(.opacity)
            }
        }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            session.refresh()
        }
        .onChange(of: session.restFinishedToken) { _, _ in
            Haptics.restFinished()
        }
    }

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: Icons.close)
                    .font(Typography.buttonLabel)
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(Theme.accent(for: colorScheme))
            .accessibilityIdentifier(A11y.Workout.close)

            Spacer()

            Text(session.sessionTitle)
                .font(Typography.buttonLabel)

            Spacer()

            Button("结束") {
                session.endWorkout()
            }
            .font(Typography.buttonLabel)
            .foregroundStyle(Theme.accent(for: colorScheme))
            .frame(minWidth: 52, minHeight: 44)
            .fixedSize()
            .accessibilityIdentifier(A11y.Workout.end)
        }
        .padding(.horizontal, 8)
        .glassSurface(radius: Theme.Radius.glassIsland)
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var finishedPlaceholder: some View {
        VStack(spacing: 12) {
            Text("本次训练完成")
                .font(.title3.weight(.semibold))
            Text("已完成 \(session.completedSets) / \(session.plannedSets) 组")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var controlDock: some View {
        VStack(spacing: 8) {
            setCounterText
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)

            ProgressBar(progress: session.progress)

            Button {
                session.completeSet()
            } label: {
                Text("完成本组")
                    .font(Typography.buttonLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                Theme.accent(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .accessibilityIdentifier(A11y.Workout.completeSet)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.52), .white.opacity(0.06)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .padding(.top, 16)

            Button {
                showDowngradeOptions = true
            } label: {
                Text("这组做不动")
                    .font(Typography.body)
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressableGlassStyle())
            .accessibilityIdentifier(A11y.Workout.downgrade)

            Button {
                showSkipOptions = true
            } label: {
                Text("跳过本组")
                    .font(Typography.secondary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PressableGlassStyle())
            .accessibilityIdentifier(A11y.Workout.skipSet)
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.glassCard)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .confirmationDialog("为什么跳过这组？", isPresented: $showSkipOptions, titleVisibility: .visible) {
            Button("没时间") { session.skipSet(reason: .noTime) }
                .accessibilityIdentifier(A11y.Workout.skipReasonNoTime)
            Button("太累了") { session.skipSet(reason: .tooHard) }
            Button("身体不适") { session.skipSet(reason: .pain) }
            Button("缺器械") { session.skipSet(reason: .noEquipment) }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog("这组做不动", isPresented: $showDowngradeOptions, titleVisibility: .visible) {
            Button(halfTargetTitle) { session.downgradeSet() }
                .accessibilityIdentifier(A11y.Workout.downgradeHalf)
            Button("取消", role: .cancel) {}
        } message: {
            Text("只改这一组，后面照原计划；这一组记作降阶完成。")
        }
    }
}
