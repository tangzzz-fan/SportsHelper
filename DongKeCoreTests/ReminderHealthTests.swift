import Foundation
import Testing
@testable import DongKeCore

@Suite("提醒健康度")
struct ReminderHealthTests {
    @Test func noTrainingDaysNeedsNothing() {
        let health = ReminderHealthEvaluator.evaluate(
            settingsEnabled: true,
            authorization: .denied,
            scheduledCount: 0,
            trainingDays: 0
        )
        #expect(health == .ok)
        #expect(health.needsAttention == false)
    }

    @Test func disabledSettingsWinOverEverything() {
        let health = ReminderHealthEvaluator.evaluate(
            settingsEnabled: false,
            authorization: .denied,
            scheduledCount: 0,
            trainingDays: 3
        )
        #expect(health == .disabled)
    }

    @Test func deniedAuthorization() {
        let health = ReminderHealthEvaluator.evaluate(
            settingsEnabled: true,
            authorization: .denied,
            scheduledCount: 0,
            trainingDays: 3
        )
        #expect(health == .denied)
    }

    @Test func undeterminedAuthorizationAsksForPermission() {
        let health = ReminderHealthEvaluator.evaluate(
            settingsEnabled: true,
            authorization: .notDetermined,
            scheduledCount: 0,
            trainingDays: 2
        )
        #expect(health == .notDetermined)
    }

    @Test func provisionalCountsAsAuthorized() {
        let health = ReminderHealthEvaluator.evaluate(
            settingsEnabled: true,
            authorization: .provisional,
            scheduledCount: 2,
            trainingDays: 2
        )
        #expect(health == .ok)
    }

    @Test func missingRemindersAreReportedAsCount() {
        let health = ReminderHealthEvaluator.evaluate(
            settingsEnabled: true,
            authorization: .authorized,
            scheduledCount: 1,
            trainingDays: 3
        )
        #expect(health == .incomplete(missing: 2))
    }

    @Test func extraRemindersAreFine() {
        let health = ReminderHealthEvaluator.evaluate(
            settingsEnabled: true,
            authorization: .authorized,
            scheduledCount: 7,
            trainingDays: 3
        )
        #expect(health == .ok)
    }

    @Test func attentionCasesExplainThemselves() {
        for health in [ReminderHealth.disabled, .denied, .notDetermined, .incomplete(missing: 1)] {
            #expect(health.needsAttention)
            #expect(health.message.isEmpty == false)
            #expect(health.actionTitle.isEmpty == false)
        }
    }

    @Test func incompleteMessageCarriesNumber() {
        #expect(ReminderHealth.incomplete(missing: 2).message.contains("2"))
    }
}
