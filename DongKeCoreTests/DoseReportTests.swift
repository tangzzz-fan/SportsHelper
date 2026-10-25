import Foundation
import Testing
@testable import DongKeCore

private let calendar = Calendar(identifier: .gregorian)

private var now: Date {
    var components = DateComponents()
    components.year = 2026
    components.month = 10
    components.day = 25
    components.hour = 20
    return calendar.date(from: components) ?? Date()
}

private func daysAgo(_ days: Int) -> Date {
    calendar.date(byAdding: .day, value: -days, to: now) ?? now
}

private func log(
    _ catalogId: String?,
    status: SetStatus = .done,
    rpe: Int? = nil,
    skip: SkipReason? = nil,
    daysAgo days: Int = 1
) -> SetLog {
    SetLog(
        sessionId: UUID(),
        prescriptionId: "1-main-1",
        catalogId: catalogId,
        setIndex: 0,
        status: status,
        plannedValue: 12,
        actualValue: status == .skipped ? 0 : 12,
        skipReason: skip,
        rpe: rpe,
        completedAt: daysAgo(days)
    )
}

@Test("有效组：做了、且不是「很轻松」")
func effectiveDefinition() {
    #expect(DoseReportBuilder.isEffective(log("squat")))
    #expect(DoseReportBuilder.isEffective(log("squat", rpe: 2)))
    #expect(DoseReportBuilder.isEffective(log("squat", rpe: 5)))
    #expect(DoseReportBuilder.isEffective(log("squat", rpe: 1)) == false)
    #expect(DoseReportBuilder.isEffective(log("squat", status: .downgraded)) == false)
    #expect(DoseReportBuilder.isEffective(log("squat", status: .skipped)) == false)
}

@Test("一组深蹲同时记到股四头与臀")
func muscleSharing() {
    let report = DoseReportBuilder.build(logs: [log("squat")], now: now, calendar: calendar)
    let quads = report.muscles.first { $0.muscle == .quads }
    let glutes = report.muscles.first { $0.muscle == .glutes }
    #expect(quads?.sets == 1)
    #expect(glutes?.sets == 1)
    #expect(report.effectiveSets == 1)
}

@Test("上周的组进「上周」，不进本周合计")
func previousWeekSeparated() {
    let logs = [log("squat", daysAgo: 1), log("squat", daysAgo: 1), log("squat", daysAgo: 8)]
    let report = DoseReportBuilder.build(logs: logs, now: now, calendar: calendar)
    #expect(report.effectiveSets == 2)
    #expect(report.muscles.first { $0.muscle == .quads }?.previous == 1)
}

@Test("只统计本周的跳过原因，按次数排序")
func skipBreakdown() {
    let logs = [
        log("squat", status: .skipped, skip: .noTime, daysAgo: 1),
        log("squat", status: .skipped, skip: .noTime, daysAgo: 2),
        log("squat", status: .skipped, skip: .pain, daysAgo: 3),
        log("squat", status: .skipped, skip: .noTime, daysAgo: 9)
    ]
    let report = DoseReportBuilder.build(logs: logs, now: now, calendar: calendar)
    #expect(report.skips.map(\.reason) == [.noTime, .pain])
    #expect(report.skips.first?.count == 2)
    #expect(report.skippedSets == 3)
}

@Test("四周趋势最后一项是本周")
func weeklyTrend() {
    let logs = [
        log("squat", daysAgo: 1),
        log("squat", daysAgo: 2),
        log("squat", daysAgo: 8),
        log("squat", daysAgo: 15)
    ]
    let report = DoseReportBuilder.build(logs: logs, now: now, calendar: calendar)
    #expect(report.weeklySets.count == 4)
    #expect(report.weeklySets.last == 2)
    #expect(report.weeklySets[2] == 1)
    #expect(report.weeklySets[1] == 1)
}

@Test("旧记录没有动作 id 时算完成、不算剂量")
func legacyLogsStayUnassigned() {
    let logs = [log(nil), log(nil)]
    let report = DoseReportBuilder.build(logs: logs, now: now, calendar: calendar)
    #expect(report.completedSets == 2)
    #expect(report.effectiveSets == 2)
    #expect(report.muscles.isEmpty)
    #expect(report.unassignedSets == 2)
}

@Test("空记录不炸")
func emptyReport() {
    let report = DoseReportBuilder.build(logs: [], now: now, calendar: calendar)
    #expect(report.isEmpty)
    #expect(report.weeklySets == [0, 0, 0, 0])
}
