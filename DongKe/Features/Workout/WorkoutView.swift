import SwiftUI
import DongKeCore

struct WorkoutView: View {
    @Bindable var session: WorkoutSession
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var prescription: ExercisePrescription? { session.currentPrescription }

    private var doseText: String {
        guard let prescription else { return "" }
        let target = prescription.target
        let unit = target.type == .durationSec ? "秒" : "次"
        let perSide = target.perSide ? " / 侧" : ""
        return "\(target.value) \(unit)\(perSide) × \(prescription.sets) 组"
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
            }

            VStack(spacing: 0) {
                navBar

                Spacer(minLength: 0)

                if let prescription {
                    VStack(spacing: 18) {
                        ExerciseFigureView(catalogId: prescription.catalogId)

                        VStack(spacing: 2) {
                            Text(prescription.name)
                                .font(.system(size: 17, weight: .semibold))
                            Text(doseText)
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
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
    }

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(Theme.accent(for: colorScheme))

            Spacer()

            Text(session.sessionTitle)
                .font(.system(size: 17, weight: .semibold))

            Spacer()

            Button("结束") {
                session.endWorkout()
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.accent(for: colorScheme))
            .frame(width: 52, height: 44)
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
            HStack(spacing: 4) {
                Text("第 \(session.currentSetIndex) 组")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("/")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("共 \(session.currentSetTotal) 组")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .monospacedDigit()

            ProgressBar(progress: session.progress)

            Button {
                session.completeSet()
            } label: {
                Text("完成本组")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(PressableGlassStyle())
            .foregroundStyle(Theme.callToActionInk(for: colorScheme))
            .background(
                Theme.accent(for: colorScheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
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
                session.downgradeSet()
            } label: {
                Text("这组做不动")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.accent(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(PressableGlassStyle())
        }
        .padding(16)
        .glassSurface(radius: Theme.Radius.glassCard)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
