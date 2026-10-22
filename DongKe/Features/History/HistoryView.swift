import SwiftUI
import DongKeCore

struct HistoryView: View {
    private let state = AppState.shared

    @Environment(\.colorScheme) private var colorScheme

    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日"
        return formatter
    }

    private var weekBars: [Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return Weekday.allCases.map { weekday in
            let matches = state.history.filter { SessionSummary in
                SampleData.weekday(for: SessionSummary.date) == weekday
            }
            guard let latest = matches.first else { return 0 }
            _ = today
            return latest.completionRate
        }
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

            VStack(alignment: .leading, spacing: 0) {
                Text("记录")
                    .font(.system(size: 34, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                summaryCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Text("最近训练")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(state.history.enumerated()), id: \.element.id) { index, item in
                        historyRow(item)
                        if index < state.history.count - 1 {
                            Divider()
                                .overlay(Color.primary.opacity(0.06))
                                .padding(.leading, 16)
                        }
                    }
                }
                .glassSurface(radius: Theme.Radius.glassCard)
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                metric(value: "\(state.completedThisWeek) / \(state.weeklyTarget)", label: "本周")
                metric(value: "\(state.streakDays) 天", label: "连续")
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(Weekday.allCases.enumerated()), id: \.offset) { index, weekday in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(weekBars[index] > 0 ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.10))
                            .frame(height: max(4, CGFloat(weekBars[index]) * 44))
                            .frame(maxWidth: .infinity)
                        Text(String(weekday.chineseName.suffix(1)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 64, alignment: .bottom)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
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
                    .font(.system(size: 16, weight: .medium))
                Text(formatter.string(from: item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int((item.completionRate * 100).rounded()))%")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(item.completionRate >= 1 ? Theme.accent(for: colorScheme) : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
