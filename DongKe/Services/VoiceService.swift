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
        let created = SpeechCueCoordinator(renderer: Self.makeRenderer())
        coordinator = created
        refreshPolicy(isForeground: true)
        holdSession()
        return created
    }

    func refreshPolicy(isForeground: Bool? = nil) {
        let policy = SpeechCuePolicy(
            isEnabled: Self.isEnabledByUser,
            isForeground: isForeground ?? (UIApplication.shared.applicationState == .active),
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
            renderer: Self.makeRenderer()
        )
        previewCoordinator = created
        created.announce(.sessionStart(title: "上肢与核心", exerciseCount: 3, totalSets: 9))
    }

    func shutdown() {
        coordinator?.stop()
        coordinator = nil
        previewCoordinator?.stop()
        previewCoordinator = nil
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
