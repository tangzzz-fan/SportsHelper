import SwiftUI
import DongKeCore

/// 训练页的重量调节。只改本次会话，不改计划、不写版本。
/// 步进先固定 2.5kg；器械档位（可调 / 固定）由后续票接。
struct LoadAdjustSheet: View {
    @Bindable var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss

    private let step: Double = 2.5

    private var prescription: ExercisePrescription? { session.currentPrescription }

    private var canReset: Bool {
        guard let id = prescription?.itemId else { return false }
        return session.loadOverrides[id] != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                if let load = session.currentLoad {
                    VStack(spacing: 4) {
                        Text(load.shortText ?? "")
                            .font(.system(size: 46, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(prescription?.name ?? "")
                            .font(Typography.secondary)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 14) {
                        Button {
                            session.adjustLoad(by: -step)
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 64, height: 46)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(A11y.Workout.loadMinus)

                        Button {
                            session.adjustLoad(by: step)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 64, height: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(A11y.Workout.loadPlus)
                    }
                    .font(.system(size: 18, weight: .semibold))

                    if canReset {
                        Button("恢复默认重量") {
                            session.resetLoad()
                        }
                        .font(Typography.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 20)
            .navigationTitle("这一组的重量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier(A11y.Workout.loadDone)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
