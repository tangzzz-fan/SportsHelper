import Foundation

struct SmokeError: Error, CustomStringConvertible {
    let description: String
}

func env(_ key: String) -> String? {
    guard let value = ProcessInfo.processInfo.environment[key] else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func makeProfile() -> UserProfile {
    var profile = UserProfile()
    profile.goal = .buildMuscle
    profile.level = .beginner
    profile.availableWeekdays = [.monday, .wednesday, .friday]
    profile.sessionMinutes = 30
    profile.equipment = [.dumbbell, .bodyweight]
    profile.injuries = ""
    return profile
}

func loggingTransport() -> AITransport {
    AITransport(sender: { request in
        let started = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let elapsed = String(format: "%.1f", Date().timeIntervalSince(started))
        print("· HTTP \(status)，\(elapsed)s，\(data.count) bytes")
        if (200..<300).contains(status) == false {
            print("  返回前 160 字：\(String(decoding: data.prefix(160), as: UTF8.self))")
        }
        return AITransport.Response(status: status, body: data)
    })
}

func report(_ draft: ParsedPlanDraft, mode: AIResponseMode, elapsed: TimeInterval) {
    guard let plan = draft.plan else {
        print("✘ 没有计划：\(draft.issues.map(\.message).joined(separator: "；"))")
        return
    }
    let trainingDays = plan.days.filter { !$0.isRestDay }
    let items = trainingDays.flatMap(\.blocks).flatMap(\.items)
    let sets = items.reduce(0) { $0 + $1.sets }

    print("")
    print("✔ 生成成功（\(mode.rawValue)，总耗时 \(String(format: "%.1f", elapsed))s）")
    print("  计划名：\(plan.meta.title)")
    print("  目标/水平：\(plan.meta.goal.chineseName) / \(plan.meta.level.chineseName)")
    print("  训练日：\(trainingDays.count) 天（声明 \(plan.meta.daysPerWeek) 天）")
    print("  动作：\(items.count) 个，总组数：\(sets)")
    for day in trainingDays.prefix(7) {
        let names = day.blocks.flatMap(\.items).map { item in
            "\(item.name) \(item.sets)×\(item.target.doseText)\(item.target.perSide ? "/侧" : "")"
        }
        print("  \(day.weekday.chineseName)：\(names.joined(separator: "、"))")
    }
    if draft.issues.isEmpty == false {
        print("  提示 \(draft.issues.count) 条：")
        for issue in draft.issues.prefix(5) {
            print("    [\(issue.severity)] \(issue.path)：\(issue.message)")
        }
    }
}

let note = CommandLine.arguments.dropFirst().joined(separator: " ")
let configuration = AIConfiguration(
    baseURL: env("DEEPSEEK_BASE_URL") ?? env("DK_AI_BASE_URL") ?? "",
    model: env("DEEPSEEK_MODEL") ?? env("DK_AI_MODEL") ?? "deepseek-flash",
    apiKey: env("DEEPSEEK_API_KEY") ?? env("DK_AI_KEY")
)

print("端点：\(configuration.trimmedBaseURL)/chat/completions")
print("模型：\(configuration.resolvedModel)")
let brief = PlanBriefParser.parse(note)
let resolved = brief.resolved(against: makeProfile())
print("原话：\(note.isEmpty ? "（无）" : note)")
print("解析为：\(resolved.weekdayText)，共 \(resolved.daysPerWeek) 天；每次 \(resolved.sessionMinutes) 分钟；\(resolved.equipmentText)；\(resolved.goal.chineseName)")
print("上限：每天 \(resolved.maxExercises) 个动作 / \(resolved.maxSets) 组")
if resolved.focus.isEmpty == false { print("重点：\(resolved.focus.joined(separator: "、"))") }
if resolved.avoid.isEmpty == false { print("避开：\(resolved.avoid.joined(separator: "、"))") }

let semaphore = DispatchSemaphore(value: 0)
let started = Date()
Task {
    do {
        guard let key = configuration.resolvedKey else { throw SmokeError(description: "缺少 API Key") }
        let request = AITransport.Request(
            url: try AIEndpoint.completionsURL(baseURL: configuration.trimmedBaseURL).get(),
            key: key,
            model: configuration.resolvedModel,
            messages: AIPromptBuilder.makeMessages(profile: makeProfile(), brief: brief)
        )
        let result = try await loggingTransport().generate(request)
        print("  响应前 120 字：\(result.text.prefix(120))")
        switch AIPlanInterpreter.interpret(result.text, memory: .empty, exercises: .empty) {
        case let .success(draft):
            report(draft, mode: result.mode, elapsed: Date().timeIntervalSince(started))
        case let .failure(error):
            print("✘ 解析失败：\(error.message)")
        }
        semaphore.signal()
    } catch {
        print("✘ \(error)")
        semaphore.signal()
        exit(1)
    }
}
semaphore.wait()
