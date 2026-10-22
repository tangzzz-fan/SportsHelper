import Foundation

public enum ChatRequestBodyBuilder {
    public static func data(model: String, messages: [ChatMessage], mode: AIResponseMode) -> Data {
        var root: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "temperature": 0.2
        ]
        if let format = responseFormat(mode) {
            root["response_format"] = format
        }
        return (try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])) ?? Data()
    }

    private static func responseFormat(_ mode: AIResponseMode) -> [String: Any]? {
        switch mode {
        case .jsonSchema:
            [
                "type": "json_schema",
                "json_schema": [
                    "name": "dongke_plan",
                    "strict": true,
                    "schema": schemaObject
                ]
            ]
        case .jsonObject:
            ["type": "json_object"]
        case .plain:
            nil
        }
    }

    private static var schemaObject: Any {
        (try? JSONSerialization.jsonObject(with: Data(PlanSchemaJSON.text.utf8))) ?? [:]
    }
}
