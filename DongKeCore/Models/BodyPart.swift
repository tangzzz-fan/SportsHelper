import Foundation

public enum BodyPart: String, CaseIterable, Codable, Sendable, Identifiable {
    case shoulderNeck
    case lowerBack
    case knee
    case hip
    case elbow
    case wrist
    case ankle

    public var id: String { rawValue }

    public var chineseName: String {
        switch self {
        case .shoulderNeck: "肩颈"
        case .lowerBack: "腰"
        case .knee: "膝"
        case .hip: "髋"
        case .elbow: "肘"
        case .wrist: "腕"
        case .ankle: "踝"
        }
    }

    public var keywords: [String] {
        switch self {
        case .shoulderNeck: ["肩颈", "颈椎", "肩膀", "肩", "脖子", "颈"]
        case .lowerBack: ["腰椎", "腰背", "下背", "腰", "背"]
        case .knee: ["膝盖", "膝"]
        case .hip: ["髋关节", "髋部", "胯", "髋"]
        case .elbow: ["手肘", "肘关节", "胳膊肘", "肘"]
        case .wrist: ["手腕", "腕"]
        case .ankle: ["脚踝", "跟腱", "踝"]
        }
    }

    static let avoidVocabulary: [String] = {
        allCases.flatMap(\.keywords).sorted { $0.count > $1.count }
    }()
}

public enum BodyPartDetector {
    public static func parts(in text: String) -> Set<BodyPart> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }
        var result: Set<BodyPart> = []
        for part in BodyPart.allCases where part.keywords.contains(where: { trimmed.contains($0) }) {
            result.insert(part)
        }
        return result
    }

    public static func parts(in texts: [String]) -> Set<BodyPart> {
        texts.reduce(into: Set<BodyPart>()) { partial, text in
            partial.formUnion(parts(in: text))
        }
    }
}
