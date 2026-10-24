import SwiftUI
import DongKeCore

struct PlanSorePicker: View {
    @Binding var soreParts: Set<BodyPart>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text("哪里不舒服？")
                    .font(.footnote.weight(.semibold))
                Text("选一下，帮你标出会让这里吃力的动作")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(BodyPart.allCases) { part in
                    chip(part)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func chip(_ part: BodyPart) -> some View {
        let on = soreParts.contains(part)
        return Button {
            if on {
                soreParts.remove(part)
            } else {
                soreParts.insert(part)
            }
        } label: {
            Text(part.chineseName)
                .font(.caption.weight(.medium))
                .foregroundStyle(on ? Color.white : Color.primary.opacity(0.7))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    on ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.07),
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(A11y.Import.sorePart).\(part.rawValue)")
    }
}

struct PlanSafetyCard: View {
    let issues: [SafetyIssue]
    let plan: WorkoutPlan
    let soreParts: Set<BodyPart>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if issues.isEmpty {
            cleanCard
        } else {
            warningCard
        }
    }

    private var names: String {
        BodyPart.allCases.filter { soreParts.contains($0) }.map(\.chineseName).joined(separator: "、")
    }

    private var cleanCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("没有动作会明显用到\(names)")
                .font(.footnote.weight(.semibold))
            Text("这份计划里没有让\(names)明显承重的动作。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.halo(for: colorScheme).opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var warningCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("有 \(issues.count) 个动作会让\(names)明显吃力")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(issues) { issue in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("·")
                    Text(lineText(issue))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier(A11y.Import.safetyNotice)
    }

    private func lineText(_ issue: SafetyIssue) -> String {
        let day = plan.days.first { $0.dayIndex == issue.dayIndex }?.weekday.chineseName ?? "第 \(issue.dayIndex + 1) 天"
        switch issue.remedy {
        case let .alternative(name):
            return "\(issue.exerciseName) · \(day) · 可换成\(name)"
        case let .regression(name):
            return "\(issue.exerciseName) · \(day) · 可降阶为\(name)"
        case .reduce:
            return "\(issue.exerciseName) · \(day) · 建议减量"
        }
    }
}

struct PlanIssueBanner: View {
    let issues: [ParseIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("有 \(issues.count) 处需要先改掉")
                .font(.footnote.weight(.semibold))
            ForEach(issues) { issue in
                Text("· \(issue.message)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
