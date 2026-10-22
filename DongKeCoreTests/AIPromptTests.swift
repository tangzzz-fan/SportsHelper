import Foundation
import Testing
@testable import DongKeCore

@Suite("AI 提示词")
struct AIPromptBuilderTests {
    private var prompt: String { AIPromptBuilder.systemPrompt() }

    @Test func messagesAreSystemThenUser() {
        let messages = AIPromptBuilder.makeMessages(profile: UserProfile(), extraNote: "别练腿")
        #expect(messages.map(\.role) == [.system, .user])
        #expect(messages.last?.content.contains("别练腿") == true)
    }

    @Test func systemPromptListsEveryCatalogId() {
        for entry in ExerciseLibrary.all {
            #expect(prompt.contains(entry.id))
        }
    }

    @Test func systemPromptCarriesSchemaContract() {
        #expect(prompt.contains("schemaVersion"))
        #expect(prompt.contains("daysPerWeek"))
        #expect(prompt.contains("cautions"))
        #expect(prompt.contains("null"))
        #expect(prompt.contains("7"))
    }

    @Test func schemaBlockIsExtractableByOwnParser() {
        guard let extracted = PlanJSONExtractor.extract(from: prompt) else {
            Issue.record("system prompt 里的 JSON 应当能被自家提取器抠出来")
            return
        }
        let object = try? JSONSerialization.jsonObject(with: Data(extracted.utf8)) as? [String: Any]
        #expect(object?["$defs"] != nil)
    }

    @Test func userBriefCarriesProfileFacts() {
        var profile = UserProfile()
        profile.heightCm = 178
        profile.weightKg = 72.5
        profile.age = 34
        profile.goal = .buildMuscle
        profile.level = .intermediate
        profile.sessionMinutes = 45
        profile.availableWeekdays = [.tuesday, .saturday]
        profile.equipment = [.dumbbell]
        profile.injuries = "左膝不适"

        let brief = AIPromptBuilder.userBrief(profile: profile, extraNote: "")
        #expect(brief.contains("178"))
        #expect(brief.contains("72.5"))
        #expect(brief.contains("34"))
        #expect(brief.contains(PlanGoal.buildMuscle.chineseName))
        #expect(brief.contains(TrainingLevel.intermediate.chineseName))
        #expect(brief.contains("45"))
        #expect(brief.contains(Weekday.tuesday.chineseName))
        #expect(brief.contains(Equipment.dumbbell.chineseName))
        #expect(brief.contains("左膝不适"))
    }

    @Test func userBriefOmitsInjuryLineWhenEmpty() {
        var profile = UserProfile()
        profile.injuries = ""
        let brief = AIPromptBuilder.userBrief(profile: profile, extraNote: "")
        #expect(brief.contains("伤病") == false)
    }
}

@Suite("计划 Schema 常量")
struct PlanSchemaJSONTests {
    private var object: [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(PlanSchemaJSON.text.utf8))) as? [String: Any] ?? [:]
    }

    @Test func parsesAsJSON() {
        #expect(object.isEmpty == false)
    }

    @Test func declaresSameVersionAsContract() {
        #expect((object["properties"] as? [String: Any])?["schemaVersion"] != nil)
        #expect(object["additionalProperties"] as? Bool == false)
    }

    @Test func hasAllSixDefinitions() {
        let defs = object["$defs"] as? [String: Any]
        #expect(Set(defs?.keys.map { $0 } ?? []) == [
            "PlanMeta", "PlanDay", "ExerciseBlock", "ExercisePrescription", "SetTarget", "Load"
        ])
    }

    @Test func mentionsEveryLibraryId() {
        for entry in ExerciseLibrary.all {
            #expect(PlanSchemaJSON.text.contains(entry.id))
        }
    }
}
