import Foundation
import Testing
@testable import DongKeCore

@Suite("AI 传输层")
struct AITransportTests {
    private let url = URL(string: "https://api.example.com/v1/chat/completions")!

    private func completion(_ text: String) -> Data {
        let object: [String: Any] = ["choices": [["message": ["content": text]]]]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    private func request() -> AITransport.Request {
        AITransport.Request(
            url: url,
            key: "sk-test",
            model: "deepseek-flash",
            messages: [ChatMessage(role: .user, content: "hi")]
        )
    }

    private func transport(
        _ script: [AITransport.Response],
        recorder: Recorder
    ) -> AITransport {
        AITransport(
            retryDelay: .milliseconds(1),
            sleep: { recorder.record(sleep: $0) },
            sender: { urlRequest in
                recorder.record(request: urlRequest)
                let index = recorder.advance()
                guard index < script.count else { throw AIClientError.transport("脚本已用完") }
                return script[index]
            }
        )
    }

    @Test("200 且内容合法时直接返回内容与档位")
    func successOnFirstMode() async throws {
        let recorder = Recorder()
        let transport = transport([AITransport.Response(status: 200, body: completion("{}"))], recorder: recorder)
        let result = try await transport.generate(request())

        #expect(result.mode == .jsonSchema)
        #expect(result.text == "{}")
        #expect(recorder.requests.count == 1)
    }

    @Test("400 且提到 response_format 时降级到下一档并成功")
    func degradesOnFormatRejection() async throws {
        let recorder = Recorder()
        let transport = transport(
            [
                AITransport.Response(status: 400, body: Data(#"{"error":"This response_format type is unavailable now"}"#.utf8)),
                AITransport.Response(status: 200, body: completion("{}"))
            ],
            recorder: recorder
        )
        let result = try await transport.generate(request())

        #expect(result.mode == .jsonObject)
        #expect(recorder.requests.count == 2)
    }

    @Test("三档都被拒时抛 requestRejected 并带上最后一次原因")
    func failsAfterAllModes() async throws {
        let recorder = Recorder()
        let transport = transport(
            [
                AITransport.Response(status: 400, body: Data(#"{"error":"response_format unsupported"}"#.utf8)),
                AITransport.Response(status: 400, body: Data(#"{"error":"json_schema unsupported"}"#.utf8)),
                AITransport.Response(status: 400, body: Data(#"{"error":"not supported"}"#.utf8))
            ],
            recorder: recorder
        )

        await #expect(throws: AIClientError.self) {
            try await transport.generate(request())
        }
        #expect(recorder.requests.count == 3)
    }

    @Test("400 但原因与格式无关时不降级，直接报被拒")
    func plainBadRequestDoesNotDegrade() async throws {
        let recorder = Recorder()
        let transport = transport(
            [AITransport.Response(status: 400, body: Data(#"{"error":"model not found"}"#.utf8))],
            recorder: recorder
        )

        await #expect(throws: AIClientError.requestRejected(400, #"{"error":"model not found"}"#)) {
            try await transport.generate(request())
        }
        #expect(recorder.requests.count == 1)
    }

    @Test("401 不重试")
    func unauthorizedDoesNotRetry() async throws {
        let recorder = Recorder()
        let transport = transport([AITransport.Response(status: 401, body: Data())], recorder: recorder)

        await #expect(throws: AIClientError.unauthorized) {
            try await transport.generate(request())
        }
        #expect(recorder.requests.count == 1)
        #expect(recorder.sleeps.isEmpty)
    }

    @Test("403 同样按未授权处理")
    func forbiddenIsUnauthorized() async throws {
        let recorder = Recorder()
        let transport = transport([AITransport.Response(status: 403, body: Data())], recorder: recorder)

        await #expect(throws: AIClientError.unauthorized) {
            try await transport.generate(request())
        }
    }

    @Test("429 先退避重试一次，再失败")
    func rateLimitRetriesOnce() async throws {
        let recorder = Recorder()
        let transport = transport(
            [
                AITransport.Response(status: 429, body: Data()),
                AITransport.Response(status: 429, body: Data())
            ],
            recorder: recorder
        )

        await #expect(throws: AIClientError.rateLimited) {
            try await transport.generate(request())
        }
        #expect(recorder.requests.count == 2)
        #expect(recorder.sleeps.count == 1)
    }

    @Test("429 后恢复时照常返回")
    func rateLimitRecoversOnRetry() async throws {
        let recorder = Recorder()
        let transport = transport(
            [AITransport.Response(status: 429, body: Data()), AITransport.Response(status: 200, body: completion("{}"))],
            recorder: recorder
        )
        let result = try await transport.generate(request())
        #expect(result.mode == .jsonSchema)
        #expect(recorder.requests.count == 2)
    }

    @Test("500 会重试，连续 5xx 最终抛 serverError")
    func serverErrorRetriesThenFails() async throws {
        let recorder = Recorder()
        let transport = transport(
            [AITransport.Response(status: 503, body: Data()), AITransport.Response(status: 503, body: Data())],
            recorder: recorder
        )

        await #expect(throws: AIClientError.serverError(503)) {
            try await transport.generate(request())
        }
        #expect(recorder.requests.count == 2)
    }

    @Test("200 但内容为空时报 emptyResponse")
    func emptyContent() async throws {
        let recorder = Recorder()
        let transport = transport([AITransport.Response(status: 200, body: completion("   "))], recorder: recorder)

        await #expect(throws: AIClientError.emptyResponse) {
            try await transport.generate(request())
        }
    }

    @Test("200 但不是 OpenAI 形状的 JSON 时报 invalidJSON")
    func nonChatCompletionBody() async throws {
        let recorder = Recorder()
        let transport = transport([AITransport.Response(status: 200, body: Data("<html>oops</html>".utf8))], recorder: recorder)

        await #expect(throws: AIClientError.invalidJSON) {
            try await transport.generate(request())
        }
    }

    @Test("网络超时映射成 timeout")
    func timeoutIsMapped() async throws {
        let transport = AITransport(
            retryDelay: .milliseconds(1),
            sleep: { _ in },
            sender: { _ in throw URLError(.timedOut) }
        )

        await #expect(throws: AIClientError.timeout) {
            try await transport.generate(request())
        }
    }

    @Test("其它网络错误映射成 transport 并带错误码")
    func otherNetworkErrorIsMapped() async throws {
        let transport = AITransport(
            retryDelay: .milliseconds(1),
            sleep: { _ in },
            sender: { _ in throw URLError(.cannotFindHost) }
        )

        await #expect(throws: AIClientError.transport("URLError \(URLError.Code.cannotFindHost.rawValue)")) {
            try await transport.generate(request())
        }
    }

    @Test("请求头带 Bearer，三档分别写不同 response_format")
    func requestBodyReflectsMode() throws {
        let base = request()
        let schema = AITransport.urlRequest(base, mode: .jsonSchema)
        let object = AITransport.urlRequest(base, mode: .jsonObject)
        let plain = AITransport.urlRequest(base, mode: .plain)

        #expect(schema.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(schema.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(schema.httpMethod == "POST")

        let schemaBody = String(decoding: schema.httpBody ?? Data(), as: UTF8.self)
        let objectBody = String(decoding: object.httpBody ?? Data(), as: UTF8.self)
        let plainBody = String(decoding: plain.httpBody ?? Data(), as: UTF8.self)

        #expect(schemaBody.contains("json_schema"))
        #expect(objectBody.contains("json_object"))
        #expect(plainBody.contains("response_format") == false)
    }

    @Test("从指定档位起步，不会回退到更高档")
    func startsAtGivenMode() async throws {
        let recorder = Recorder()
        let transport = transport(
            [
                AITransport.Response(status: 400, body: Data(#"{"error":"json_schema unsupported"}"#.utf8)),
                AITransport.Response(status: 200, body: completion("{}"))
            ],
            recorder: recorder
        )
        let result = try await transport.generate(request(), startingAt: .jsonObject)

        #expect(result.mode == .plain)
        #expect(recorder.requests.count == 2)
    }
}

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    private var _sleeps: [Duration] = []
    private var cursor = 0

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _requests
    }

    var sleeps: [Duration] {
        lock.lock()
        defer { lock.unlock() }
        return _sleeps
    }

    func record(request: URLRequest) {
        lock.lock()
        _requests.append(request)
        lock.unlock()
    }

    func record(sleep: Duration) {
        lock.lock()
        _sleeps.append(sleep)
        lock.unlock()
    }

    func advance() -> Int {
        lock.lock()
        defer { lock.unlock() }
        cursor += 1
        return cursor - 1
    }
}
