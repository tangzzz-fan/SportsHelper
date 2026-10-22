import Foundation

public struct FigurePlayback: Equatable, Sendable {
    public let motion: FigureMotion
    public let frameCount: Int
    public private(set) var index: Int
    public private(set) var isPlaying: Bool

    public init(motion: FigureMotion, frameCount: Int) {
        self.motion = motion
        self.frameCount = max(0, frameCount)
        self.index = 0
        self.isPlaying = false
    }

    public var canPlay: Bool {
        motion == .loop && frameCount > 1
    }

    public var displayedIndex: Int {
        guard frameCount > 0 else { return 0 }
        if motion == .hold { return 0 }
        return min(index, frameCount - 1)
    }

    public mutating func toggle() {
        guard canPlay else { return }
        isPlaying.toggle()
        if !isPlaying { index = 0 }
    }

    public mutating func advance() {
        guard canPlay, isPlaying, frameCount > 0 else { return }
        index = (index + 1) % frameCount
    }

    public mutating func stop() {
        isPlaying = false
        index = 0
    }
}

public struct FigurePlaybackCoordinator: Sendable {
    public private(set) var playingFigureID: String?

    public init() {}

    public mutating func beganPlaying(_ id: String) {
        playingFigureID = id
    }

    public mutating func stopped(_ id: String) {
        if playingFigureID == id { playingFigureID = nil }
    }

    public func isPlaying(_ id: String) -> Bool {
        playingFigureID == id
    }
}
