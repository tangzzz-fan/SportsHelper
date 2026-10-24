import Foundation
import Testing
@testable import DongKeCore

@Suite("AI 请求体契约")
struct AIRequestBodyTests {
    private func body(_ mode: AIResponseMode) -> [String: Any] {
        let data = ChatRequestBodyBuilder.data(
            model: "gpt-4o-mini",
            messages: AIPromptBuilder.makeMessages(profile: UserProfile(), extraNote: ""),
            mode: mode
        )
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }

    @Test func sendsModelMessagesAndTemperature() {
        let json = body(.jsonSchema)
        #expect(json["model"] as? String == "gpt-4o-mini")
        #expect(json["temperature"] as? Double == 0.2)
        let messages = json["messages"] as? [[String: Any]]
        #expect(messages?.count == 2)
        #expect(messages?.first?["role"] as? String == "system")
        #expect(messages?.last?["role"] as? String == "user")
    }

    @Test func neverSendsStreamOrMaxTokens() {
        for mode in AIResponseMode.allCases {
            let json = body(mode)
            #expect(json["stream"] == nil)
            #expect(json["max_tokens"] == nil)
            #expect(json["max_completion_tokens"] == nil)
        }
    }

    @Test func jsonSchemaModeCarriesStrictSchema() {
        let format = body(.jsonSchema)["response_format"] as? [String: Any]
        #expect(format?["type"] as? String == "json_schema")
        let schema = format?["json_schema"] as? [String: Any]
        #expect(schema?["name"] as? String == "dongke_plan")
        #expect(schema?["strict"] as? Bool == true)
        let payload = schema?["schema"] as? [String: Any]
        #expect(payload?["required"] as? [String] == ["schemaVersion", "meta", "days", "cautions"])
        #expect((payload?["$defs"] as? [String: Any])?.count == 6)
    }

    @Test func jsonObjectModeOnlyAsksForObject() {
        let format = body(.jsonObject)["response_format"] as? [String: Any]
        #expect(format?.count == 1)
        #expect(format?["type"] as? String == "json_object")
    }

    @Test func plainModeOmitsResponseFormat() {
        #expect(body(.plain)["response_format"] == nil)
    }

    @Test("提示词列出库里每一个动作，扩库不会漏")
    func systemPromptListsEveryCatalogId() {
        let prompt = AIPromptBuilder.systemPrompt()
        let listed = Set(prompt.matches(of: /([a-z][a-z0-9_]+)\(/).map { String($0.output.1) })
        let missing = ExerciseLibrary.identifiers.subtracting(listed)
        #expect(missing.isEmpty, "提示词里缺这些动作：\(missing.sorted())")
    }

    @Test func degradationOrderIsFixed() {
        #expect(AIResponseMode.jsonSchema.next == .jsonObject)
        #expect(AIResponseMode.jsonObject.next == .plain)
        #expect(AIResponseMode.plain.next == nil)
    }
}

@Suite("AI 响应映射")
struct AIResponseMappingTests {
    private func completion(_ content: String) -> Data {
        let payload: [String: Any] = [
            "choices": [["message": ["role": "assistant", "content": content]]]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    @Test func extractsContentFromChoices() {
        #expect(AIResponseMapper.outcome(status: 200, body: completion("{}")) == .content("{}"))
    }

    @Test func emptyContentIsEmptyResponse() {
        #expect(AIResponseMapper.outcome(status: 200, body: completion("")) == .failure(.emptyResponse))
    }

    @Test func nonJSONBodyIsInvalidJSON() {
        #expect(AIResponseMapper.outcome(status: 200, body: Data("oops".utf8)) == .failure(.invalidJSON))
    }

    @Test func unauthorizedStatuses() {
        #expect(AIResponseMapper.outcome(status: 401, body: Data()) == .failure(.unauthorized))
        #expect(AIResponseMapper.outcome(status: 403, body: Data()) == .failure(.unauthorized))
    }

    @Test func rateLimitedStatus() {
        #expect(AIResponseMapper.outcome(status: 429, body: Data()) == .failure(.rateLimited))
    }

    @Test func serverErrorKeepsCode() {
        #expect(AIResponseMapper.outcome(status: 503, body: Data()) == .failure(.serverError(503)))
    }

    @Test func rejectsOnlyWhenErrorPointsAtResponseFormat() {
        let body = Data(#"{"error":{"message":"Invalid parameter: response_format is not supported"}}"#.utf8)
        guard case .degrade = AIResponseMapper.outcome(status: 400, body: body) else {
            Issue.record("应当判定为可降级")
            return
        }
    }

    @Test func otherBadRequestIsNotADegradeSignal() {
        let body = Data(#"{"error":{"message":"model not found"}}"#.utf8)
        guard case let .failure(error) = AIResponseMapper.outcome(status: 400, body: body) else {
            Issue.record("不该降级")
            return
        }
        guard case let .requestRejected(code, detail) = error else {
            Issue.record("应当映射成 requestRejected，实际 \(error)")
            return
        }
        #expect(code == 400)
        #expect(detail.contains("model not found"))
    }

    @Test func notFoundKeepsBodyForTheUser() {
        let body = Data("404 page not found".utf8)
        guard case let .failure(.requestRejected(404, detail)) = AIResponseMapper.outcome(status: 404, body: body) else {
            Issue.record("404 应当带原文交给用户")
            return
        }
        #expect(detail.contains("page not found"))
    }

    @Test func timeoutMapsToTimeout() {
        #expect(AIResponseMapper.transportError(URLError(.timedOut)) == .timeout)
    }

    @Test func offlineMapsToTransport() {
        guard case .transport = AIResponseMapper.transportError(URLError(.notConnectedToInternet)) else {
            Issue.record("离线应当映射成 transport")
            return
        }
    }
}

@Suite("AI 错误文案")
struct AIClientErrorTests {
    private var all: [AIClientError] {
        [
            .missingKey, .invalidBaseURL, .unauthorized, .rateLimited,
            .serverError(500), .requestRejected(400, "model not found"), .timeout,
            .transport("x"), .emptyResponse, .invalidJSON, .schemaMismatch("days 缺 2 天")
        ]
    }

    @Test func everyErrorHasChineseActionableMessage() {
        for error in all {
            #expect(error.message.isEmpty == false)
            #expect(error.message.contains("Error") == false)
            #expect(error.message.contains("错误") == false)
        }
    }

    @Test func onlyTransientFailuresAreRetryable() {
        #expect(AIClientError.rateLimited.isRetryable)
        #expect(AIClientError.serverError(500).isRetryable)
        #expect(AIClientError.serverError(503).isRetryable)
        #expect(AIClientError.timeout.isRetryable)
        #expect(AIClientError.unauthorized.isRetryable == false)
        #expect(AIClientError.invalidJSON.isRetryable == false)
        #expect(AIClientError.serverError(400).isRetryable == false)
        #expect(AIClientError.requestRejected(400, "x").isRetryable == false)
    }
}

@Suite("AI 端点归一化")
struct AIEndpointTests {
    @Test func rejectsPlainHTTP() {
        #expect(AIEndpoint.completionsURL(baseURL: "http://api.example.com") == .failure(.invalidBaseURL))
    }

    @Test func rejectsUnparsable() {
        #expect(AIEndpoint.completionsURL(baseURL: "  ") == .failure(.invalidBaseURL))
        #expect(AIEndpoint.completionsURL(baseURL: "api.example.com") == .failure(.invalidBaseURL))
    }

    @Test func appendsPathAndTrimsTrailingSlash() {
        let url = try! AIEndpoint.completionsURL(baseURL: "https://api.example.com/v1/").get()
        #expect(url.absoluteString == "https://api.example.com/v1/chat/completions")
    }

    @Test func keepsExistingCompletionsPath() {
        let url = try! AIEndpoint.completionsURL(baseURL: "https://api.example.com/v1/chat/completions").get()
        #expect(url.absoluteString == "https://api.example.com/v1/chat/completions")
    }

    @Test func doesNotDuplicateV1() {
        let url = try! AIEndpoint.completionsURL(baseURL: "https://api.deepseek.com").get()
        #expect(url.absoluteString == "https://api.deepseek.com/chat/completions")
    }
}

@Suite("AI 输出解释")
struct AIPlanInterpreterTests {
    @Test func strictSchemaJSONBecomesPlan() {
        let result = AIPlanInterpreter.interpret(validPlanJSON())
        guard case let .success(draft) = result else {
            Issue.record("合法 JSON 应当解析成功")
            return
        }
        #expect(draft.plan != nil)
        #expect(draft.path == .strictJSON)
    }

    @Test func fencedJSONIsAccepted() {
        let fenced = "```json\n\(validPlanJSON())\n```"
        #expect(AIPlanInterpreter.interpret(fenced).isSuccess)
    }

    @Test func proseIsRejectedAsInvalidJSON() {
        #expect(AIPlanInterpreter.interpret("好的，给你一份计划：周一深蹲 4 组").failure == .invalidJSON)
    }

    @Test func wrongStructureIsSchemaMismatch() {
        let result = AIPlanInterpreter.interpret(#"{"title":"x","days":[]}"#)
        guard case let .failure(error) = result else {
            Issue.record("结构不符应当失败")
            return
        }
        guard case .schemaMismatch = error else {
            Issue.record("应当是 schemaMismatch，实际 \(error)")
            return
        }
    }

    @Test func blankIsEmptyResponse() {
        #expect(AIPlanInterpreter.interpret("   ").failure == .emptyResponse)
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var failure: Failure? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
