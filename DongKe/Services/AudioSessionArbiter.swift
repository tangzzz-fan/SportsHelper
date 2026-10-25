import AVFoundation
import DongKeCore
import os

private let sessionLog = Logger(subsystem: "app.dongke.ios", category: "audio-session")

@MainActor
final class AudioSessionArbiter {
    static let shared = AudioSessionArbiter()

    /// 一条中断订阅。
    ///
    /// 闭包本身无法弱引用，所以弱引用的是**注册者**，由它决定这条订阅的寿命。
    private struct Listener {
        weak var owner: AnyObject?
        let handler: () -> Void
    }

    private var lease = AudioSessionLease()
    private var listeners: [Listener] = []
    /// block 版 `addObserver` **不会**因为 token 释放而自动注销——丢掉 token 等于
    /// 「永远无法取消观察」，token 对象本身也丢在系统里。必须留住它。
    /// deinit 是 nonisolated，所以这一项不挂 actor 隔离（deinit 独占访问，安全）。
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    private var isObserving = false

    private init() {}

    deinit {
        let center = NotificationCenter.default
        for token in observers {
            center.removeObserver(token)
        }
    }

    /// 注册中断 / 拔耳机回调。
    ///
    /// - Parameter owner: 回调属于谁。注册者释放后这条订阅会被剪掉。
    ///
    /// 原来是 `listeners: [() -> Void]` 且只增不减：语音输入每点一次麦克风就会
    /// 新建一个转写器，每个 `init` 往数组里塞一条闭包、永不移除。旧闭包连同它
    /// 捕获的上下文一直留在单例里，`notifyListeners()` 还得逐个调一遍死对象。
    func observeInterruptions(of owner: AnyObject, _ handler: @escaping () -> Void) {
        pruneDeadListeners()
        listeners.append(Listener(owner: owner, handler: handler))
        startObservingIfNeeded()
    }

    func borrow(_ mode: AudioSessionLease.Mode) {
        apply(lease.borrow(mode))
    }

    func give(_ mode: AudioSessionLease.Mode) {
        apply(lease.give(mode))
    }

    private func apply(_ transition: AudioSessionLeaseTransition) {
        let session = AVAudioSession.sharedInstance()
        switch transition {
        case .none:
            break
        case let .activate(mode):
            do {
                switch mode {
                case .playback:
                    try session.setCategory(.ambient, mode: .spokenAudio, options: [.mixWithOthers])
                case .record:
                    try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers, .allowBluetoothHFP])
                }
                try session.setActive(true)
                sessionLog.notice("activate \(String(describing: mode), privacy: .public)")
            } catch {
                sessionLog.error("activate \(String(describing: mode), privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                notifyListeners()
            }
        case .deactivate:
            try? session.setActive(false, options: [.notifyOthersOnDeactivation])
            sessionLog.notice("deactivate")
        }
    }

    private func startObservingIfNeeded() {
        guard isObserving == false else { return }
        isObserving = true
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: raw) == .began
                else { return }
                Task { @MainActor in self?.notifyListeners() }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                guard let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable
                else { return }
                Task { @MainActor in self?.notifyListeners() }
            }
        )
    }

    private func notifyListeners() {
        pruneDeadListeners()
        for listener in listeners {
            listener.handler()
        }
    }

    private func pruneDeadListeners() {
        listeners.removeAll { $0.owner == nil }
    }
}
