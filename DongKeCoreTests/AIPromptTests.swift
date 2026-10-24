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

    @Test func userBriefCapsDailyVolumeBySessionLength() {
        var profile = UserProfile()
        profile.sessionMinutes = 30
        let brief = AIPromptBuilder.userBrief(profile: profile, extraNote: "")
        #expect(brief.contains("不超过 5 个"))
        #expect(brief.contains("不超过 15 组"))
        #expect(brief.contains("±15%"))
    }

    @Test func actionCapNeverExceedsSetCapAtThreeSetsEach() {
        for minutes in stride(from: 5, through: 120, by: 5) {
            var profile = UserProfile()
            profile.sessionMinutes = minutes
            let effective = PlanBrief(sentence: "").resolved(against: profile)
            #expect(effective.maxExercises * 3 <= effective.maxSets)
            #expect(effective.maxExercises >= 2)
        }
    }

    @Test func volumeCapScalesWithLongerSessions() {
        var profile = UserProfile()
        profile.sessionMinutes = 60
        let brief = AIPromptBuilder.userBrief(profile: profile, extraNote: "")
        #expect(brief.contains("不超过 8 个"))
        #expect(brief.contains("不超过 30 组"))
    }

    @Test func briefOverridesProfileAndKeepsInjuries() {
        var profile = UserProfile()
        profile.sessionMinutes = 30
        profile.availableWeekdays = [.monday, .wednesday, .friday]
        profile.equipment = [.bodyweight]
        profile.injuries = "左膝不适"

        let brief = PlanBriefParser.parse("每周二四，每次 45 分钟，有弹力带，想增肌，重点背部和肩，别跳跃")
        let text = AIPromptBuilder.userBrief(profile: profile, brief: brief)

        #expect(text.contains("周二、周四"))
        #expect(text.contains("共 2 天"))
        #expect(text.contains("45"))
        #expect(text.contains("弹力带"))
        #expect(text.contains(PlanGoal.buildMuscle.chineseName))
        #expect(text.contains("背部"))
        #expect(text.contains("肩部"))
        #expect(text.contains("跳跃"))
        #expect(text.contains("左膝不适"))
        #expect(text.contains("用户原话"))
        #expect(text.contains("meta.daysPerWeek 必须等于 2"))
    }

    @Test func emptyBriefFallsBackToProfile() {
        let profile = UserProfile()
        let text = AIPromptBuilder.userBrief(profile: profile, brief: PlanBriefParser.parse(""))
        #expect(text.contains("按档案生成"))
        #expect(text.contains("周一、周三、周五"))
        #expect(text.contains("30 分钟"))
    }

    @Test func briefAndExtraNoteShareCopyablePrompt() {
        var profile = UserProfile()
        profile.injuries = "腰不好"
        let brief = PlanBriefParser.parse("每周四天，每次 40 分钟，有哑铃")
        let text = AIPromptBuilder.copyablePrompt(profile: profile, brief: brief)
        #expect(text.hasPrefix("你是健身计划生成器"))
        #expect(text.contains("共 4 天"))
        #expect(text.contains("腰不好"))
    }

    @Test func avoidDoesNotReplaceInjuries() {
        var profile = UserProfile()
        profile.injuries = "右肩有伤"
        let brief = PlanBriefParser.parse("不要深蹲")
        let text = AIPromptBuilder.userBrief(profile: profile, brief: brief)
        #expect(text.contains("深蹲"))
        #expect(text.contains("右肩有伤"))
    }

    @Test func copyablePromptKeepsBothHalves() {
        var profile = UserProfile()
        profile.sessionMinutes = 45
        let text = AIPromptBuilder.copyablePrompt(profile: profile)
        #expect(text.hasPrefix("你是健身计划生成器"))
        #expect(text.contains("45"))
        #expect(text.contains("schemaVersion"))
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
        // 清单由 systemPrompt 第 4 条动态生成；schema 只定义结构，不再维护一份易漂移的 id 列表
        let prompt = AIPromptBuilder.systemPrompt()
        for entry in ExerciseLibrary.all {
            #expect(prompt.contains(entry.id), "提示词里没有 \(entry.id)")
        }
    }

    @Test func schemaDoesNotHardcodeCatalogIds() {
        #expect(PlanSchemaJSON.text.contains("例如 squat、push_up") == false,
                "schema 里还留着一份会漂移的动作清单")
    }
}
