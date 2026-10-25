import Foundation
import UIKit
import DongKeCore
import os

private let voicePolicyLog = Logger(subsystem: "app.dongke.ios", category: "voice-policy")

@MainActor
final class VoiceService {
    static let shared = VoiceService()

    private var coordinator: SpeechCueCoordinator?
    private var previewCoordinator: SpeechCueCoordinator?
    /// 全 App 只留一个出声引擎。
    ///
    /// 以前每次 `activeCoordinator()` / `preview()` 都新建一个渲染器，也就新建一个
    /// `AVSpeechSynthesizer`。两个 synthesizer 各自排队，上一句没念完就再 `speak` 时
    /// 会依次念完——听感就是「两个音频」。现在引擎只有一个，谁都不能背着别人出声。
    private var renderer: SpeechRendering?
    private var workoutVoice: (sessionId: UUID, voice: WorkoutVoiceSession)?
    private var holdsSession = false

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPolicy() }
        }
    }

    var isAvailable: Bool {
        coordinator != nil
    }

    static var voiceName: String {
        VoicePicker.bestChinese().name
    }

    static var isEnhancedVoice: Bool {
        VoicePicker.bestChinese().isEnhanced
    }

    func activeCoordinator() -> SpeechCueCoordinator {
        if let coordinator {
            refreshPolicy(isForeground: true)
            holdSession()
            return coordinator
        }
        let created = SpeechCueCoordinator(renderer: sharedRenderer())
        coordinator = created
        refreshPolicy(isForeground: true)
        holdSession()
        return created
    }

    /// 一节课只有一个播报会话。
    ///
    /// 播报会话原来由视图自己持有：`onAppear` 建一个、`onDisappear` 置空。
    /// fullScreenCover 的呈现动画会成对触发这两个回调，于是同一节课会建出
    /// 第二、第三个会话，每个都会念一遍开场——真机日志里同一句出现过三次。
    /// 现在按 `sessionId` 缓存，视图重建多少次都拿回同一个实例。
    func voice(
        for sessionId: UUID,
        plan: WorkoutPlan,
        dayIndex: Int,
        steps: [FlowStep]
    ) -> WorkoutVoiceSession {
        if let workoutVoice, workoutVoice.sessionId == sessionId {
            return workoutVoice.voice
        }
        workoutVoice?.voice.stop()
        let created = WorkoutVoiceSession(
            plan: plan,
            dayIndex: dayIndex,
            coordinator: activeCoordinator(),
            steps: steps
        )
        workoutVoice = (sessionId, created)
        return created
    }

    func endVoice(sessionId: UUID) {
        guard let workoutVoice, workoutVoice.sessionId == sessionId else { return }
        workoutVoice.voice.stop()
        self.workoutVoice = nil
    }

    func refreshPolicy(isForeground: Bool? = nil) {
        // `.inactive` 不是「不在前台」：下拉控制中心、来电横幅、fullScreenCover 转场
        // 都会短暂进入 `.inactive`。以前把它当后台处理，播报会在转场瞬间被掐断，
        // 会话也跟着释放再重新激活——日志里那串 deactivate / activate 就是它。
        let policy = SpeechCuePolicy(
            isEnabled: Self.isEnabledByUser,
            isForeground: isForeground ?? (UIApplication.shared.applicationState != .background),
            isVoiceOverRunning: UIAccessibility.isVoiceOverRunning
        )
        coordinator?.policy = policy
        if policy.allowsSpeech, coordinator != nil {
            holdSession()
        } else {
            releaseSession()
        }
        voicePolicyLog.notice(
            "policy enabled=\(policy.isEnabled, privacy: .public) foreground=\(policy.isForeground, privacy: .public) voiceOver=\(policy.isVoiceOverRunning, privacy: .public) allows=\(policy.allowsSpeech, privacy: .public) coordinator=\(self.coordinator != nil, privacy: .public) held=\(self.holdsSession, privacy: .public)"
        )
    }

    /// 整节课按住音频会话。
    ///
    /// 每句播报自己 `setActive(true)` 时，真机上重新激活要 100–300ms，短句（倒数 3/2/1）
    /// 会被吞掉开头甚至整句——GymMane 用「循环播放静音文件」绕开的就是这个坑。
    /// 这里改成整节课持有一份租约，渲染器再按句借还，归零只在课程结束时发生。
    private func holdSession() {
        guard holdsSession == false else { return }
        holdsSession = true
        AudioSessionArbiter.shared.borrow(.playback)
    }

    private func releaseSession() {
        guard holdsSession else { return }
        holdsSession = false
        AudioSessionArbiter.shared.give(.playback)
    }

    func preview() {
        previewCoordinator?.stop()
        let created = SpeechCueCoordinator(
            policy: SpeechCuePolicy(isEnabled: true, isForeground: true, isVoiceOverRunning: false),
            renderer: sharedRenderer()
        )
        previewCoordinator = created
        created.announce(.sessionStart(exerciseCount: 3, totalSets: 9))
    }

    func shutdown() {
        coordinator?.stop()
        coordinator = nil
        previewCoordinator?.stop()
        previewCoordinator = nil
        workoutVoice?.voice.stop()
        workoutVoice = nil
        releaseSession()
    }

    static var levelByUser: VoiceLevel {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_VOICE_ENABLED"] == "1" {
            return .standard
        }
        #endif
        return VoiceSettingsStore.shared.level
    }

    static var isEnabledByUser: Bool {
        levelByUser.isEnabled
    }

    private func sharedRenderer() -> SpeechRendering {
        if let renderer { return renderer }
        let created = Self.makeRenderer()
        renderer = created
        return created
    }

    private static func makeRenderer() -> SpeechRendering {
        #if DEBUG
        if ProcessInfo.processInfo.environment["DK_VOICE_FAKE"] == "1" {
            return FileLoggingRenderer()
        }
        if ProcessInfo.processInfo.environment["DK_VOICE_CLIPS"] == "0" {
            return SystemSpeechRenderer()
        }
        #endif
        // 音条在就用音条，缺片段的句子自己回落到系统 TTS（ClipSpeechRenderer 内部处理）。
        if let clips = ClipSpeechRenderer.makeIfAvailable() { return clips }
        return SystemSpeechRenderer()
    }
}

#if DEBUG
@MainActor
final class FileLoggingRenderer: SpeechRendering {
    private let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("dk-voice.log")

    var availability: SpeechAvailability { .ready }

    var profile: SpeechProfile {
        SpeechProfile(engineId: "file", voiceName: "调试日志", charactersPerSecond: 4.2)
    }

    func prepare() {}

    func render(_ request: SpeechRequest, on event: @escaping (SpeechOutputEvent) -> Void) {
        append(request.text)
        event(.started(request.id))
        event(.finished(request.id, seconds: 0))
    }

    func cancel() {}

    private func append(_ text: String) {
        let data = (text + "\n").data(using: .utf8)
        guard let data else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url)
        }
    }
}
#endif
