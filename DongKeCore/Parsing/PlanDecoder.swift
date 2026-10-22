import Foundation

public enum PlanDecodeError: Error, Equatable {
    case emptyInput
    case tooLarge
    case noJSONObject
    case schemaMismatch([ParseIssue])
}

public enum PlanDecoder {
    private static let maxBytes = 64 * 1024
    private static let supportedSchemaVersion = 1

    public static func decode(_ json: String) throws -> WorkoutPlan {
        try decodeStrict(payload(from: json))
    }

    public static func decodeLenient(_ json: String) throws -> (plan: WorkoutPlan, issues: [ParseIssue]) {
        let (patched, issues) = fillDefaults(in: try payload(from: json))
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: patched, options: [])
        } catch {
            throw PlanDecodeError.noJSONObject
        }
        return (try decodeStrict(data), issues)
    }

    private static func payload(from text: String) throws -> Data {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PlanDecodeError.emptyInput }
        guard trimmed.utf8.count <= maxBytes else { throw PlanDecodeError.tooLarge }
        guard let extracted = PlanJSONExtractor.extract(from: trimmed),
              let data = extracted.data(using: .utf8) else {
            throw PlanDecodeError.noJSONObject
        }
        return data
    }

    private static func decodeStrict(_ data: Data) throws -> WorkoutPlan {
        let plan: WorkoutPlan
        do {
            plan = try JSONDecoder().decode(WorkoutPlan.self, from: data)
        } catch {
            throw PlanDecodeError.schemaMismatch([
                ParseIssue(path: "root", severity: .error, message: "计划结构与契约不符，缺少必填字段或类型不一致")
            ])
        }
        guard plan.schemaVersion == supportedSchemaVersion else {
            throw PlanDecodeError.schemaMismatch([
                ParseIssue(
                    path: "schemaVersion",
                    severity: .error,
                    message: "不支持的计划结构版本 \(plan.schemaVersion)"
                )
            ])
        }
        return plan
    }

    private static func fillDefaults(in data: Data) -> ([String: Any], [ParseIssue]) {
        guard var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return ([:], [ParseIssue(path: "root", severity: .error, message: "不是合法的 JSON 对象")])
        }

        var issues: [ParseIssue] = []

        if root["cautions"] == nil {
            root["cautions"] = []
            issues.append(ParseIssue(path: "cautions", severity: .warning, message: "缺少注意事项，已按空列表补齐"))
        }

        var meta = root["meta"] as? [String: Any] ?? [:]
        if meta["notes"] == nil {
            meta["notes"] = ""
            issues.append(ParseIssue(path: "meta.notes", severity: .warning, message: "缺少计划说明，已按空串补齐"))
        }
        root["meta"] = meta

        guard var days = root["days"] as? [Any] else {
            return (root, issues)
        }

        for dayOffset in days.indices {
            guard var day = days[dayOffset] as? [String: Any] else { continue }
            if day["notes"] == nil { day["notes"] = "" }
            if day["scheduledTime"] == nil { day["scheduledTime"] = "" }
            if day["estimatedMinutes"] == nil { day["estimatedMinutes"] = 0 }
            if day["isRestDay"] == nil { day["isRestDay"] = false }

            var blocks = day["blocks"] as? [Any] ?? []
            for blockOffset in blocks.indices {
                guard var block = blocks[blockOffset] as? [String: Any] else { continue }
                if block["notes"] == nil { block["notes"] = "" }
                if block["restBetweenItemsSec"] == nil { block["restBetweenItemsSec"] = 0 }
                if block["restBetweenRoundsSec"] == nil { block["restBetweenRoundsSec"] = 0 }
                if block["rounds"] == nil { block["rounds"] = 1 }

                var items = block["items"] as? [Any] ?? []
                for itemOffset in items.indices {
                    guard var item = items[itemOffset] as? [String: Any] else { continue }
                    if item["restSec"] == nil {
                        item["restSec"] = 60
                        issues.append(ParseIssue(
                            path: "days[\(dayOffset)].blocks[\(blockOffset)].items[\(itemOffset)].restSec",
                            severity: .warning,
                            message: "缺少组间休息，已按 60 秒补齐"
                        ))
                    }
                    if item["tempo"] == nil { item["tempo"] = "" }
                    if item["load"] == nil { item["load"] = ["type": "bodyweight", "value": 0] }
                    if item["notes"] == nil { item["notes"] = "" }
                    items[itemOffset] = item
                }
                block["items"] = items
                blocks[blockOffset] = block
            }
            day["blocks"] = blocks
            days[dayOffset] = day
        }
        root["days"] = days
        return (root, issues)
    }
}
