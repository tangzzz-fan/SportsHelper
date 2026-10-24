import Foundation

// 用真实 API 跑一遍「提示词 → 响应 → 解析 → 校验」，只依赖 DongKeCore。
// 用法：scripts/ai-smoke.sh "重点练手臂和核心，不要跳跃动作"

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

func send(_ request: URLRequest) async throws -> (Int, Data) {
    let (data, response) = try await URLSession.shared.data(for: request)
    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
    return (status, data)
}

func generate(
    configuration: AIConfiguration,
    profile: UserProfile,
    brief: PlanBrief
) async throws -> (draft: ParsedPlanDraft, mode: AIResponseMode) {
    let url = try AIEndpoint.completionsURL(baseURL: configuration.trimmedBaseURL).get()
    let key = try configuration.resolvedKey ?? { throw SmokeError(description: "缺少 API Key") }()
    let messages = AIPromptBuilder.makeMessages(profile: profile, brief: brief)

    var mode: AIResponseMode? = .jsonSchema
    var lastRejection = ""
    while let current = mode {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = ChatRequestBodyBuilder.data(
            model: configuration.resolvedModel,
            messages: messages,
            mode: current
        )

        let started = Date()
        let (status, body) = try await send(request)
        let elapsed = Date().timeIntervalSince(started)
        print("· \(current.rawValue): HTTP \(status), \(String(format: "%.1f", elapsed))s, \(body.count) bytes")

        switch AIResponseMapper.outcome(status: status, body: body) {
        case .content(let text):
            print("  响应前 120 字：\(text.prefix(120))")
            switch AIPlanInterpreter.interpret(text) {
            case .success(let draft):
                return (draft, current)
            case .failure(let error):
                throw SmokeError(description: "解析失败：\(error.message)")
            }
        case .degrade(let snippet):
            lastRejection = snippet
            print("  降级原因：\(snippet.prefix(120))")
            mode = current.next
        case .failure(let error):
            throw SmokeError(description: "请求失败：\(error.message)")
        }
    }
    throw SmokeError(description: "三档都失败，最后一次：\(lastRejection)")
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
print("补充要求：\(note.isEmpty ? "（无）" : note)")
print("解析为：\(resolved.weekdayText)，共 \(resolved.daysPerWeek) 天；每次 \(resolved.sessionMinutes) 分钟；\(resolved.equipmentText)；\(resolved.goal.chineseName)")
if resolved.focus.isEmpty == false { print("重点：\(resolved.focus.joined(separator: "、"))") }
if resolved.avoid.isEmpty == false { print("避开：\(resolved.avoid.joined(separator: "、"))") }

let semaphore = DispatchSemaphore(value: 0)
let started = Date()
Task {
    do {
        let result = try await generate(configuration: configuration, profile: makeProfile(), brief: brief)
        report(result.draft, mode: result.mode, elapsed: Date().timeIntervalSince(started))
        semaphore.signal()
    } catch {
        print("✘ \(error)")
        semaphore.signal()
        exit(1)
    }
}
semaphore.wait()
