import Foundation

public enum PlanJSONExtractor {
    public static func extract(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let fenced = fencedBody(in: trimmed), let value = normalize(fenced) {
            return value
        }
        if let object = balanced(in: trimmed, open: "{", close: "}") {
            return normalize(object)
        }
        if let array = balanced(in: trimmed, open: "[", close: "]") {
            return normalize(array)
        }
        return nil
    }

    private static func fencedBody(in text: String) -> String? {
        guard let openRange = text.range(of: "```") else { return nil }
        let rest = text[openRange.upperBound...]
        guard let closeRange = rest.range(of: "```") else { return nil }
        var body = String(rest[..<closeRange.lowerBound])
        if let newline = body.firstIndex(of: "\n") {
            let head = body[..<newline].trimmingCharacters(in: .whitespaces)
            if !head.contains("{") && !head.contains("[") {
                body = String(body[body.index(after: newline)...])
            }
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func balanced(in text: String, open: Character, close: Character) -> String? {
        var depth = 0
        var inString = false
        var escaped = false
        var startIndex: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else if character == "\"" {
                inString = true
            } else if character == open {
                if depth == 0 { startIndex = index }
                depth += 1
            } else if character == close {
                depth -= 1
                if depth == 0, let start = startIndex {
                    return String(text[start...index])
                }
                if depth < 0 { return nil }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func normalize(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard text.hasPrefix("["), text.hasSuffix("]") else { return text }

        let inner = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard inner.hasPrefix("{"), inner.hasSuffix("}") else { return text }
        guard let object = balanced(in: inner, open: "{", close: "}"), object == inner else { return text }
        return object
    }
}
