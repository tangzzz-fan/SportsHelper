import AVFoundation
import DongKeCore
import os

private let clipLog = Logger(subsystem: "app.dongke.ios", category: "voice-clips")

/// 阶段 0 的原型：把预录好的短语拼起来播，替代实时 TTS。
///
/// 只做一件事——**验证拼接感能不能接受**。音条目前由 macOS `say` 渲染，
/// 只能内部试听、不能随包上架（Apple 语音仅授权个人使用）。正式音条要换
/// CosyVoice2 重渲染，见 `.scratch/coach-voice/README.md`。
///
/// 拼接不上（自由文本、超范围数字、AI 生成的主题名）就整句交回系统 TTS，
/// 不允许静默。
@MainActor
final class ClipSpeechRenderer: SpeechRendering {
    private let sampleRate: Double = 22_050
    private let gapSeconds: Double = 0.07

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let fallback = SystemSpeechRenderer()

    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var current: SpeechRequest?
    private var onEvent: ((SpeechOutputEvent) -> Void)?
    private var playToken: UUID?
    private var holdsLease = false
    private var isEngineReady = false
    private let folder: URL?

    static func makeIfAvailable() -> ClipSpeechRenderer? {
        let renderer = ClipSpeechRenderer()
        guard renderer.hasClips else { return nil }
        return renderer
    }

    init(folder: URL? = Bundle.main.resourceURL?.appendingPathComponent("VoiceClips")) {
        self.folder = folder
        AudioSessionArbiter.shared.observeInterruptions(of: self) { [weak self] in
            self?.cancel()
        }
    }

    var hasClips: Bool {
        guard let folder,
              let items = try? FileManager.default.contentsOfDirectory(atPath: folder.path)
        else { return false }
        return items.contains { $0.hasSuffix(".wav") }
    }

    var availability: SpeechAvailability {
        hasClips ? .ready : .unsupported
    }

    var profile: SpeechProfile {
        SpeechProfile(engineId: "clips", voiceName: "音条库", charactersPerSecond: 4.2)
    }

    func prepare() {
        startEngineIfNeeded()
    }

    func render(_ request: SpeechRequest, on event: @escaping (SpeechOutputEvent) -> Void) {
        // 换句前先掐掉上一句。音条走 AVAudioPlayerNode、回落走系统 TTS，
        // 是两条音轨；不先停就可能一条在播、另一条开始说话。
        if current != nil { cancel() }
        fallback.cancel()

        let plan = VoiceClipBank.plan(for: request.text)
        let segments = plan.segments
        guard segments.isEmpty == false, let buffer = buffer(for: segments) else {
            clipLog.notice("clip fallback text=\(request.text, privacy: .public)")
            fallback.render(request, on: event)
            return
        }

        startEngineIfNeeded()
        // 引擎起不来就没有播完的回调，此时借租约等于永久占用（会话不释放、
        // 之后所有播报都被判成「已在播」）。直接整句回落系统 TTS。
        guard isEngineReady else {
            clipLog.error("clip engine not ready, fallback text=\(request.text, privacy: .public)")
            fallback.render(request, on: event)
            return
        }
        acquireLease()
        current = request
        self.onEvent = event
        let token = UUID()
        playToken = token
        event(.started(request.id))

        let seconds = Double(buffer.frameLength) / sampleRate
        clipLog.notice(
            "clip play segments=\(segments.count, privacy: .public) seconds=\(seconds, format: .fixed(precision: 2), privacy: .public) text=\(request.text, privacy: .public)"
        )

        player.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                guard let self, self.playToken == token else { return }
                self.finish(request.id, seconds: seconds)
            }
        }
        if player.isPlaying == false { player.play() }
    }

    func cancel() {
        playToken = nil
        fallback.cancel()
        guard let current else {
            releaseLease()
            return
        }
        self.current = nil
        player.stop()
        player.play()
        clipLog.notice("clip cancel text=\(current.text, privacy: .public)")
        releaseLease()
    }

    private func finish(_ id: UUID, seconds: Double) {
        current = nil
        playToken = nil
        onEvent?(.finished(id, seconds: seconds))
        releaseLease()
    }

    private func startEngineIfNeeded() {
        guard isEngineReady == false, let format else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            isEngineReady = true
        } catch {
            clipLog.error("clip engine failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func buffer(for segments: [String]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        var pieces: [AVAudioPCMBuffer] = []
        for segment in segments {
            guard let piece = load(segment) else { return nil }
            pieces.append(piece)
        }
        let gap = AVAudioFrameCount(sampleRate * gapSeconds)
        let total = pieces.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
            + gap * AVAudioFrameCount(max(0, pieces.count - 1))
        guard total > 0, let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total),
              let destination = out.floatChannelData?[0]
        else { return nil }
        out.frameLength = total

        var offset: AVAudioFrameCount = 0
        for (index, piece) in pieces.enumerated() {
            if index > 0 {
                memset(destination + Int(offset), 0, Int(gap) * MemoryLayout<Float>.size)
                offset += gap
            }
            guard let source = piece.floatChannelData?[0] else { return nil }
            memcpy(destination + Int(offset), source, Int(piece.frameLength) * MemoryLayout<Float>.size)
            offset += piece.frameLength
        }
        return out
    }

    private func load(_ phrase: String) -> AVAudioPCMBuffer? {
        let id = VoiceClipBank.clipId(for: phrase)
        if let cached = cache[id] { return cached }
        guard let folder, let format else { return nil }
        let url = folder.appendingPathComponent("\(id).wav")
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        guard abs(file.processingFormat.sampleRate - sampleRate) < 1,
              file.processingFormat.channelCount == 1,
              file.length > 0,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(file.length)
              )
        else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        cache[id] = buffer
        return buffer
    }

    private func acquireLease() {
        guard holdsLease == false else { return }
        holdsLease = true
        AudioSessionArbiter.shared.borrow(.playback)
    }

    private func releaseLease() {
        guard holdsLease else { return }
        holdsLease = false
        AudioSessionArbiter.shared.give(.playback)
    }
}
