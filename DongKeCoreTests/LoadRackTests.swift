import Foundation
import Testing

@testable import DongKeCore

struct LoadRackTests {
    @Test func adjustableStepsUpFromWhereverYouAre() {
        let rack = LoadRack.step25
        #expect(rack.next(after: 8) == 10)
        #expect(rack.next(after: 8.8) == 10)
        #expect(rack.next(after: 10) == 12.5)
    }

    @Test func adjustableWithFiveKiloSteps() {
        let rack = LoadRack.step5
        #expect(rack.next(after: 8) == 10)
        #expect(rack.next(after: 10) == 15)
    }

    @Test func noStepFromZero() {
        #expect(LoadRack.step25.next(after: 0) == nil)
    }

    @Test func fixedRackOnlyOffersWhatYouOwn() {
        let rack = LoadRack.fixedDumbbells
        #expect(rack.next(after: 8) == 10)
        #expect(rack.next(after: 9) == 10)
        #expect(rack.next(after: 24) == nil)
    }

    @Test func snappingLandsOnARealWeight() {
        let fixed = LoadRack.fixedDumbbells
        #expect(fixed.snapped(9.2) == 10)
        #expect(fixed.snapped(30) == 24)
        #expect(LoadRack.step25.snapped(8.7) == 7.5)
    }

    @Test func rackSurvivesRoundTrip() throws {
        let rack = LoadRack.fixedDumbbells
        let decoded = try JSONDecoder().decode(LoadRack.self, from: JSONEncoder().encode(rack))
        #expect(decoded == rack)
    }

    @Test func titlesSayWhatTheRackIs() {
        #expect(LoadRack.step25.title.contains("2.5"))
        #expect(LoadRack.fixedDumbbells.title.contains("8"))
    }
}
