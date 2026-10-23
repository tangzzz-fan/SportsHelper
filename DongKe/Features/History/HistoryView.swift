import Charts
import SwiftUI
import DongKeCore

struct HistoryView: View {
    var weeklyTarget: Int = 3

    @Environment(SessionStore.self) private var store

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
            let matches = store.sessions.filter { SessionSummary in
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

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("记录")
                        .font(Typography.pageTitle)
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

                    if store.sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("还没有训练记录")
                                .font(Typography.rowTitle)
                            Text("完成一次训练后，这里会出现完成率与连续天数。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassSurface(radius: Theme.Radius.glassCard)
                        .padding(.horizontal, 16)
                    } else {
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

                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .contentMargins(.bottom, 96, for: .scrollContent)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 28) {
                metric(value: "\(store.completedDaysThisWeek) / \(weeklyTarget)", label: "本周")
                metric(value: "\(store.streakDays) 天", label: "连续")
                Spacer()
            }

            Chart {
                ForEach(Array(Weekday.allCases.enumerated()), id: \.offset) { index, weekday in
                    BarMark(
                        x: .value("星期", String(weekday.chineseName.suffix(1))),
                        y: .value("完成率", max(0.09, weekBars[index]))
                    )
                    .foregroundStyle(
                        weekBars[index] > 0 ? Theme.accent(for: colorScheme) : Color.primary.opacity(0.10)
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
            .frame(height: 72)
            .accessibilityIdentifier(A11y.History.weekChart)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: Theme.Radius.glassCard)
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
