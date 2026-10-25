import Charts
import SwiftUI
import DongKeCore

struct HistoryView: View {
    var weeklyTarget: Int = 3

    @Environment(SessionStore.self) private var store
    @Environment(SetLogStore.self) private var setLogStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var report = DoseReport()
    @State private var acceptedThisWeek = 0

    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(
                colors: [Theme.halo(for: colorScheme), .clear],
                center: .init(x: 0.85, y: 0.08),
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("记录")
                        .font(Typography.pageTitle)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    doseCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if report.muscles.isEmpty == false {
                        muscleCard
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    if report.isEmpty == false {
                        trendCard
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    if report.skips.isEmpty == false {
                        skipCard
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }

                    Text("最近训练")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    if store.sessions.isEmpty {
                        emptyCard
                    } else {
                        sessionCard
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.bottom, 96, for: .scrollContent)
        }
        .task(id: store.sessions.count) {
            reload()
        }
    }

    private func reload() {
        report = DoseReportBuilder.build(logs: setLogStore.recentLogs())
        let start = HistoryStats.weekStart(for: Date(), calendar: Calendar(identifier: .gregorian))
        let days = Set(ProposalMemo.shared.memory.acceptedChanges
            .filter { $0.at >= start }
            .map { Calendar.current.startOfDay(for: $0.at) })
        acceptedThisWeek = days.count
    }

    private var doseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                metric(value: "\(report.effectiveSets)", label: "本周有效组")
                metric(value: "\(store.completedDaysThisWeek) / \(weeklyTarget)", label: "训练天")
                metric(value: "\(store.streakDays) 天", label: "连续")
                Spacer()
            }

            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private var footnote: String {
        guard report.isEmpty == false else {
            return "练完一组记下来，这里会告诉你这一周每块肌肉练了几组。"
        }
        var parts = ["完成 \(report.completedSets) 组"]
        if report.extraSets > 0 {
            parts.append("额外 \(report.extraSets) 组")
        }
        if report.skippedSets > 0 {
            parts.append("跳过 \(report.skippedSets) 组")
        }
        if acceptedThisWeek > 0 {
            parts.append("计划改过 \(acceptedThisWeek) 次")
        }
        return parts.joined(separator: " · ")
    }

    private var muscleCard: some View {
        let peak = max(1, report.muscles.map(\.sets).max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("这周练到哪儿")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(report.muscles) { dose in
                muscleRow(dose, peak: peak)
            }

            if report.unassignedSets > 0 {
                Text("另有 \(report.unassignedSets) 组没有动作归属（旧版本记录），没算进上面的分布。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func muscleRow(_ dose: DoseReport.MuscleDose, peak: Int) -> some View {
        HStack(spacing: 10) {
            Text(dose.muscle.chineseName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Theme.accent(for: colorScheme))
                        .frame(width: max(4, proxy.size.width * Double(dose.sets) / Double(peak)))
                }
            }
            .frame(height: 8)

            Text("\(dose.sets)")
                .font(Typography.secondary.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(dose.sets == 0 ? Color.secondary : Color.primary)
                .frame(width: 22, alignment: .trailing)

            Text(deltaText(dose))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func deltaText(_ dose: DoseReport.MuscleDose) -> String {
        if dose.previous == 0 {
            return dose.sets > 0 ? "新" : "—"
        }
        if dose.delta == 0 { return "持平" }
        return dose.delta > 0 ? "↑\(dose.delta)" : "↓\(-dose.delta)"
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("四周有效组")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart {
                ForEach(Array(report.weeklySets.enumerated()), id: \.offset) { index, value in
                    BarMark(
                        x: .value("周", weekLabel(index)),
                        y: .value("有效组", value)
                    )
                    .foregroundStyle(
                        index == report.weeklySets.count - 1
                            ? Theme.accent(for: colorScheme)
                            : Color.primary.opacity(0.18)
                    )
                    .cornerRadius(3)
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(height: 68)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func weekLabel(_ index: Int) -> String {
        let remaining = report.weeklySets.count - 1 - index
        return remaining == 0 ? "本周" : "\(remaining) 周前"
    }

    private var skipCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("为什么没做")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(report.skips) { slice in
                    Text("\(slice.reason.chineseName) \(slice.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有训练记录")
                .font(Typography.rowTitle)
            Text("完成一次训练后，这里会出现这周的剂量、四周走势和最近几次。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
        .padding(.horizontal, 16)
    }

    private var sessionCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.sessions.enumerated()), id: \.element.id) { index, item in
                historyRow(item)
                if index < store.sessions.count - 1 {
                    Divider()
                        .overlay(Color.primary.opacity(0.06))
                        .padding(.leading, 16)
                }
            }
        }
        .glassSurface(radius: Theme.Radius.glassCard)
        .padding(.horizontal, 16)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(Typography.detailTitle)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func historyRow(_ item: SessionSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Typography.rowTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Text(formatter.string(from: item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Text("\(Int((item.completionRate * 100).rounded()))%")
                .font(Typography.secondary.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(item.completionRate >= 1 ? Theme.accent(for: colorScheme) : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
