import Foundation
import Testing

@testable import DongKeCore

struct SetLogLoadTests {
    private func log(load: Load?) -> SetLog {
        SetLog(
            sessionId: UUID(),
            prescriptionId: "p1",
            catalogId: "squat",
            targetType: .reps,
            setIndex: 1,
            status: .done,
            plannedValue: 12,
            actualValue: 12,
            actualLoad: load,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test func loadSurvivesRoundTrip() throws {
        let original = log(load: Load(type: .dumbbell, value: 10))
        let decoded = try JSONDecoder().decode(
            SetLog.self,
            from: JSONEncoder().encode(original)
        )
        #expect(decoded.actualLoad == Load(type: .dumbbell, value: 10))
    }

    @Test func bodyweightLoadSurvivesRoundTrip() throws {
        let original = log(load: Load(type: .bodyweight, value: 0))
        let decoded = try JSONDecoder().decode(
            SetLog.self,
            from: JSONEncoder().encode(original)
        )
        #expect(decoded.actualLoad == Load(type: .bodyweight, value: 0))
    }

    @Test func nilLoadSurvivesRoundTrip() throws {
        let decoded = try JSONDecoder().decode(
            SetLog.self,
            from: JSONEncoder().encode(log(load: nil))
        )
        #expect(decoded.actualLoad == nil)
    }

    @Test func legacyPayloadWithoutLoadDecodesToNil() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "sessionId": "\(UUID().uuidString)",
          "prescriptionId": "p1",
          "catalogId": "squat",
          "targetType": "reps",
          "setIndex": 1,
          "status": "done",
          "plannedValue": 12,
          "actualValue": 12,
          "completedAt": 0,
          "origin": "prescribed"
        }
        """
        let decoded = try JSONDecoder().decode(SetLog.self, from: Data(json.utf8))
        #expect(decoded.actualLoad == nil)
        #expect(decoded.actualValue == 12)
    }

    @Test func unknownLoadTypeDecodesToNilInsteadOfThrowing() throws {
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "sessionId": "\(UUID().uuidString)",
          "prescriptionId": "p1",
          "catalogId": "squat",
          "targetType": "reps",
          "setIndex": 1,
          "status": "done",
          "plannedValue": 12,
          "actualValue": 12,
          "actualLoad": { "type": "sled", "value": 20 },
          "completedAt": 0,
          "origin": "prescribed"
        }
        """
        #expect(throws: Never.self) {
            let decoded = try JSONDecoder().decode(SetLog.self, from: Data(json.utf8))
            #expect(decoded.actualLoad == nil)
        }
    }
}
