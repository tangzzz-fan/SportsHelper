import Foundation

public struct AudioSessionLease: Equatable, Sendable {
    public enum Mode: Equatable, Sendable {
        case playback
        case record
    }

    public private(set) var playbackCount = 0
    public private(set) var recordCount = 0

    public init() {}

    public var count: Int {
        playbackCount + recordCount
    }

    public mutating func borrow(_ mode: Mode) -> AudioSessionLeaseTransition {
        switch mode {
        case .playback:
            playbackCount += 1
            return count == 1 ? .activate(.playback) : .none
        case .record:
            recordCount += 1
            return recordCount == 1 ? .activate(.record) : .none
        }
    }

    public mutating func give(_ mode: Mode) -> AudioSessionLeaseTransition {
        guard count > 0 else { return .none }
        switch mode {
        case .playback:
            playbackCount = max(0, playbackCount - 1)
        case .record:
            recordCount = max(0, recordCount - 1)
        }
        guard count == 0 else {
            if mode == .record, recordCount == 0, playbackCount > 0 {
                return .activate(.playback)
            }
            return .none
        }
        return .deactivate
    }
}

public enum AudioSessionLeaseTransition: Equatable, Sendable {
    case none
    case activate(AudioSessionLease.Mode)
    case deactivate
}
