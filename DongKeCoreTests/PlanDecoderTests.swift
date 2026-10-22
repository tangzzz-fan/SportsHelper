import Testing
@testable import DongKeCore

@Suite("PlanDecoder")
struct PlanDecoderTests {
    @Test func decodesValidDocument() throws {
        let plan = try PlanDecoder.decode(validPlanJSON())
        #expect(plan.days.count == 7)
        #expect(plan.days[0].blocks[0].items[0].sets == 4)
        #expect(plan.days[0].scheduledTime == TimeOfDay(hour: 20, minute: 30))
        #expect(plan.meta.daysPerWeek == 1)
        #expect(plan.cautions == ["关节疼痛须停训"])
    }

    @Test func rejectsDocumentMissingRequiredField() {
        do {
            _ = try PlanDecoder.decode("{\"schemaVersion\":1,\"meta\":{},\"days\":[],\"cautions\":[]}")
            Issue.record("缺字段的文档不应解码成功")
        } catch {
        }
    }

    @Test func rejectsUnknownSchemaVersion() {
        do {
            _ = try PlanDecoder.decode(validPlanJSON(schemaVersion: 99))
            Issue.record("未知 schemaVersion 不应解码成功")
        } catch {
        }
    }

    @Test func lenientParserFillsMissingRest() throws {
        let result = try PlanDecoder.decodeLenient(validPlanJSON(includeRest: false))
        #expect(result.plan.days[0].blocks[0].items[0].restSec == 60)
        #expect(result.issues.contains { $0.path.contains("restSec") })
    }
}
