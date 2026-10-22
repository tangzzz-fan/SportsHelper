import Foundation

public enum ParseSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct ParseIssue: Codable, Equatable, Identifiable, Sendable {
    public var path: String
    public var severity: ParseSeverity
    public var message: String

    public var id: String { "\(path)#\(severity.rawValue)#\(message)" }

    public init(path: String, severity: ParseSeverity, message: String) {
        self.path = path
        self.severity = severity
        self.message = message
    }
}

public enum ParsePath: String, Codable, Sendable {
    case strictJSON
    case lenientJSON
    case freeText
    case blank
}

public struct GuessedRow: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case approximate(modifier: String)
        case memory
    }

    public var originalName: String
    public var catalogName: String
    public var kind: Kind

    public init(originalName: String, catalogName: String, kind: Kind) {
        self.originalName = originalName
        self.catalogName = catalogName
        self.kind = kind
    }

    public var modifier: String? {
        if case let .approximate(modifier) = kind { return modifier }
        return nil
    }

    public var isMemory: Bool { kind == .memory }
}

public struct ParsedPlanDraft: Equatable, Sendable {
    public var plan: WorkoutPlan?
    public var issues: [ParseIssue]
    public var rawText: String
    public var path: ParsePath
    public var assumptions: [String]
    public var unmappedNames: [String]
    public var guessedItems: [String: GuessedRow]

    public var needsReview: Bool {
        path != .strictJSON || !issues.isEmpty
    }

    public var hasBlockingIssues: Bool {
        issues.contains { $0.severity == .error }
    }

    public init(
        plan: WorkoutPlan?,
        issues: [ParseIssue],
        rawText: String,
        path: ParsePath,
        assumptions: [String] = [],
        unmappedNames: [String] = [],
        guessedItems: [String: GuessedRow] = [:]
    ) {
        self.plan = plan
        self.issues = issues
        self.rawText = rawText
        self.path = path
        self.assumptions = assumptions
        self.unmappedNames = unmappedNames
        self.guessedItems = guessedItems
    }

    public static func empty(rawText: String) -> ParsedPlanDraft {
        ParsedPlanDraft(
            plan: nil,
            issues: [ParseIssue(path: "root", severity: .error, message: "未能从这段内容里识别出动作")],
            rawText: rawText,
            path: .blank
        )
    }
}
