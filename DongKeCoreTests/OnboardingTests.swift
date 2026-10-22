import Testing
import Foundation
@testable import DongKeCore

@Suite("Onboarding")
struct OnboardingTests {

    @Test("step one rejects an out-of-range height")
    func basicsRange() {
        var draft = OnboardingDraft()
        draft.profile.heightCm = 90
        #expect(draft.isStepValid(.basics) == false)
        draft.profile.heightCm = 175
        #expect(draft.isStepValid(.basics))
    }

    @Test("step one rejects an out-of-range weight and age")
    func basicsWeightAndAge() {
        var draft = OnboardingDraft()
        draft.profile.weightKg = 12
        #expect(draft.isStepValid(.basics) == false)
        draft.profile.weightKg = 70
        draft.profile.age = 8
        #expect(draft.isStepValid(.basics) == false)
        draft.profile.age = 32
        #expect(draft.isStepValid(.basics))
    }

    @Test("availability needs at least one weekday and one equipment")
    func availabilityNeedsSelection() {
        var draft = OnboardingDraft()
        draft.profile.availableWeekdays = []
        #expect(draft.isStepValid(.availability) == false)
        draft.profile.availableWeekdays = [.tuesday]
        draft.profile.equipment = []
        #expect(draft.isStepValid(.availability) == false)
        draft.profile.equipment = [.bodyweight]
        #expect(draft.isStepValid(.availability))
    }

    @Test("session length must be one of the offered options")
    func sessionOptions() {
        var draft = OnboardingDraft()
        draft.profile.sessionMinutes = 33
        #expect(draft.isStepValid(.level) == false)
        draft.profile.sessionMinutes = 45
        #expect(draft.isStepValid(.level))
    }

    @Test("toggling a weekday adds it in order and removes it again")
    func toggleWeekday() {
        var draft = OnboardingDraft()
        draft.profile.availableWeekdays = [.monday, .sunday]
        draft.toggleWeekday(.wednesday)
        #expect(draft.profile.availableWeekdays == [.monday, .wednesday, .sunday])
        draft.toggleWeekday(.monday)
        #expect(draft.profile.availableWeekdays == [.wednesday, .sunday])
    }

    @Test("the last equipment cannot be deselected")
    func lastEquipmentStays() {
        var draft = OnboardingDraft()
        draft.profile.equipment = [.dumbbell]
        draft.toggleEquipment(.dumbbell)
        #expect(draft.profile.equipment == [.dumbbell])
        draft.toggleEquipment(.band)
        #expect(draft.profile.equipment.count == 2)
    }

    @Test("the draft is complete only when every step validates")
    func completeness() {
        var draft = OnboardingDraft()
        #expect(draft.isComplete)
        draft.profile.availableWeekdays = []
        #expect(draft.isComplete == false)
    }

    @Test("completing stamps the onboarding date")
    func stampsDate() {
        let draft = OnboardingDraft()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let profile = draft.completedProfile(now: now)
        #expect(profile.onboardedAt == now)
    }

    @Test("five steps exactly, as frozen in the baseline")
    func stepCount() {
        #expect(OnboardingStep.allCases.count == 5)
        #expect(OnboardingStep.healthAndReminder.total == 5)
    }
}
