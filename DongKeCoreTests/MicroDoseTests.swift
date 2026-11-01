import Foundation
import Testing

@testable import DongKeCore

struct MicroDoseTests {
    private let day = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    private func profile(
        equipment: [Equipment] = [.bodyweight],
        injuries: String = ""
    ) -> UserProfile {
        UserProfile(equipment: equipment, injuries: injuries)
    }

    @Test func picksSomethingFromTheNonStrengthPool() {
        let dose = MicroDosePlanner.pick(profile: profile(), plan: nil, on: day, calendar: calendar)
        let entry = dose.flatMap { ExerciseLibrary.entry(for: $0.catalogId) }
        #expect(entry != nil)
        #expect(entry?.purposes.contains(.strength) == false)
    }

    @Test func isStableWithinADay() {
        let first = MicroDosePlanner.pick(profile: profile(), plan: nil, on: day, calendar: calendar)
        let second = MicroDosePlanner.pick(profile: profile(), plan: nil, on: day.addingTimeInterval(3_600), calendar: calendar)
        #expect(first?.catalogId == second?.catalogId)
    }

    @Test func prefersWhatRelievesTheSoreSpot() {
        let injuries = "肩颈不舒服"
        let dose = MicroDosePlanner.pick(
            profile: profile(injuries: injuries),
            plan: nil,
            on: day,
            calendar: calendar
        )
        let entry = dose.flatMap { ExerciseLibrary.entry(for: $0.catalogId) }
        let parts = BodyPartDetector.parts(in: injuries)
        #expect(entry?.relievedParts.isDisjoint(with: parts) == false)
        #expect(dose?.reason == "肩颈活动")
    }

    @Test func neverPicksSomethingThatHitsTheSoreSpot() {
        let injuries = "膝盖疼"
        let dose = MicroDosePlanner.pick(
            profile: profile(injuries: injuries),
            plan: nil,
            on: day,
            calendar: calendar
        )
        let entry = dose.flatMap { ExerciseLibrary.entry(for: $0.catalogId) }
        #expect(entry?.affectedParts.isDisjoint(with: BodyPartDetector.parts(in: injuries)) == true)
    }

    @Test func neverPicksEquipmentTheUserDoesNotHave() {
        let dose = MicroDosePlanner.pick(profile: profile(equipment: [.bodyweight]), plan: nil, on: day, calendar: calendar)
        #expect(dose.map { ExerciseLibrary.entry(for: $0.catalogId)?.equipment == .bodyweight } == true)
    }

    @Test func returnsNilWithoutAnyCandidate() {
        let dose = MicroDosePlanner.pick(profile: profile(equipment: []), plan: nil, on: day, calendar: calendar)
        #expect(dose == nil)
    }

    @Test func prescriptionIsThreeByFortyWithTwentyRest() {
        let dose = MicroDosePlanner.pick(profile: profile(), plan: nil, on: day, calendar: calendar)
        #expect(dose?.sets == 3)
        #expect(dose?.seconds == 40)
        #expect(dose?.restSec == 20)
        #expect(dose?.totalSeconds == 160)
        #expect((dose?.totalSeconds ?? .max) <= 180)
    }
}
