import Foundation

public enum AIClientError: Error, Equatable, Sendable {
    case missingKey
    case invalidBaseURL
    case unauthorized
    case rateLimited
    case serverError(Int)
    case requestRejected(Int, String)
    case timeout
    case transport(String)
    case emptyResponse
    case invalidJSON
    case schemaMismatch(String)

    public var message: String {
        switch self {
        case .missingKey:
            "还没有配置 API Key，可以在设置里填，也可以改用粘贴导入"
        case .invalidBaseURL:
            "接口地址需要以 https:// 开头"
        case .unauthorized:
            "API Key 被拒绝，检查是否填错或额度用尽"
        case .rateLimited:
            "请求太频繁，10 秒后可重试"
        case let .serverError(code):
            "模型服务暂时不可用（\(code)），稍后重试或改用粘贴导入"
        case let .requestRejected(code, detail):
            detail.isEmpty
                ? "接口拒绝了这次请求（\(code)），检查模型名与接口地址后重试"
                : "接口拒绝了这次请求（\(code)）：\(detail)"
        case .timeout:
            "生成超过 60 秒，已中断。可以重试，或改用粘贴导入"
        case .transport:
            "网络不通，检查网络后重试"
        case .emptyResponse:
            "模型没有返回内容，重试一次"
        case .invalidJSON:
            "模型返回的不是 JSON，改用粘贴导入更稳"
        case let .schemaMismatch(detail):
            "生成结果结构与要求不符：\(detail)。可以手动修正，或改用粘贴导入"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout:
            true
        case let .serverError(code):
            code >= 500
        default:
            false
        }
    }

    public var needsKeyFix: Bool {
        self == .unauthorized || self == .missingKey
    }
}
