import SwiftUI
import DongKeCore

/// 训练页的零件：完成区、余力、次数加成。搬出来是因为 `WorkoutView` 本身已经顶到
/// 单文件 500 行的门禁；这里只挪位置，不改行为。
extension WorkoutView {
    var finishedPlaceholder: some View {
        VStack(spacing: 12) {
            Text("本次训练完成")
                .font(.title3.weight(.semibold))
            Text("已完成 \(session.completedSets) / \(session.plannedSets) 组")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if session.extraSetsCompleted > 0 {
                Text("另有 \(session.extraSetsCompleted) 组额外加练")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let done = weeklyDone {
                Text(done)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(A11y.Workout.weeklyProgress)
            }
        }
    }

    var weeklyDone: String? {
        guard let store = session.store else { return nil }
        let target = session.plan.meta.weeklyTarget(skipped: DaySkipStore.shared.skippedThisWeek())
        return "本周 \(min(store.completedDaysThisWeek, target)) / \(target)"
    }

    var completeButtonTitle: String {
        guard bonusReps > 0, let target = session.currentTarget else { return "完成本组" }
        return "完成 \(target.value + bonusReps) 次"
    }

    var bonusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("比目标多做几个")
                .font(Typography.capsLabel)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0...3, id: \.self) { value in
                    chip(value == 0 ? "刚好" : "+\(value)", on: bonusReps == value) {
                        bonusReps = value
                    }
                    .accessibilityIdentifier(A11y.Workout.bonusReps(value))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var effortRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(effortTitle)
                .font(Typography.capsLabel)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { level in
                    chip(effortLabel(level), on: effort == level) {
                        effort = effort == level ? nil : level
                    }
                    .accessibilityIdentifier(A11y.Workout.effort(level))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var isHoldTarget: Bool {
        session.currentTarget?.type == .durationSec
    }

    var effortTitle: String {
        isHoldTarget ? "这组还能撑几秒？不选也行" : "这组还剩几次力气？不选也行"
    }

    func effortLabel(_ level: Int) -> String {
        if isHoldTarget {
            switch level {
            case 1: return "很轻松"
            case 2: return "还能 10 秒"
            case 3: return "还能 5 秒"
            case 4: return "还能 2 秒"
            default: return "已经力竭"
            }
        }
        switch level {
        case 1: return "很轻松"
        case 2: return "还能 3 次"
        case 3: return "还能 2 次"
        case 4: return "还能 1 次"
        default: return "已经力竭"
        }
    }

    func chip(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Typography.capsLabel.weight(.medium))
                .foregroundStyle(on ? Theme.callToActionInk(for: colorScheme) : Color.primary.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 9)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    on ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.07),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(PressableGlassStyle())
    }
}
