import Testing
@testable import DongKeCore

@Suite("PlanJSONExtractor")
struct PlanJSONExtractorTests {
    @Test func extractsFencedJSON() {
        let text = "好的，这是计划：\n```json\n{\"a\":1}\n```\n希望有帮助"
        #expect(PlanJSONExtractor.extract(from: text) == "{\"a\":1}")
    }

    @Test func extractsWithBracesInsideString() {
        let text = "prefix {\"note\":\"keep {this} inside\",\"n\":1} suffix"
        #expect(PlanJSONExtractor.extract(from: text) == "{\"note\":\"keep {this} inside\",\"n\":1}")
    }

    @Test func unwrapsSingleElementArray() {
        #expect(PlanJSONExtractor.extract(from: "[{\"a\":1}]") == "{\"a\":1}")
    }

    @Test func returnsNilForTextWithoutJSON() {
        #expect(PlanJSONExtractor.extract(from: "") == nil)
        #expect(PlanJSONExtractor.extract(from: "今天练一下胸吧") == nil)
    }

    @Test func extractsFromProseAroundJSON() {
        let text = "这是你的计划：{\"days\":[]}。祝顺利。"
        #expect(PlanJSONExtractor.extract(from: text) == "{\"days\":[]}")
    }
}
