import AVFoundation
import DongKeCore
import os

private let sessionLog = Logger(subsystem: "app.dongke.ios", category: "audio-session")

@MainActor
final class AudioSessionArbiter {
    static let shared = AudioSessionArbiter()

    private var lease = AudioSessionLease()
    private var listeners: [() -> Void] = []
    private var isObserving = false

    private init() {}

    func onInterruption(_ handler: @escaping () -> Void) {
        listeners.append(handler)
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
                    try session.setCategory(.record, mode: .measurement, options: [.mixWithOthers, .allowBluetooth])
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
    }

    private func notifyListeners() {
        listeners.forEach { $0() }
    }
}
