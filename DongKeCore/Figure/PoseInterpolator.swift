import Foundation

public struct FigurePoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct FigurePose: Codable, Equatable, Sendable {
    public var points: [String: FigurePoint]

    public init(points: [String: FigurePoint]) {
        self.points = points
    }
}

public struct FigureBone: Codable, Equatable, Sendable {
    public var from: String
    public var to: String

    public init(from: String, to: String) {
        self.from = from
        self.to = to
    }
}

public struct FigureSpec: Codable, Equatable, Sendable {
    public var catalogId: String
    public var loopSeconds: Double
    public var poses: [FigurePose]
    public var bones: [FigureBone]

    public init(catalogId: String, loopSeconds: Double, poses: [FigurePose], bones: [FigureBone]) {
        self.catalogId = catalogId
        self.loopSeconds = loopSeconds
        self.poses = poses
        self.bones = bones
    }
}

public enum PoseInterpolator {
    public static func pose(_ spec: FigureSpec, phase: Double) -> FigurePose {
        guard let first = spec.poses.first else { return FigurePose(points: [:]) }
        guard spec.poses.count > 1 else { return first }

        let clamped = min(max(phase, 0), 1)
        let scaled = clamped * Double(spec.poses.count - 1)
        let lowerIndex = Int(scaled.rounded(.down))
        let upperIndex = min(lowerIndex + 1, spec.poses.count - 1)
        guard lowerIndex != upperIndex else { return spec.poses[lowerIndex] }

        return blend(spec.poses[lowerIndex], spec.poses[upperIndex], scaled - Double(lowerIndex))
    }

    private static func blend(_ from: FigurePose, _ to: FigurePose, _ progress: Double) -> FigurePose {
        var points = from.points
        for (key, target) in to.points {
            guard let source = from.points[key] else {
                points[key] = target
                continue
            }
            points[key] = FigurePoint(
                x: source.x + (target.x - source.x) * progress,
                y: source.y + (target.y - source.y) * progress
            )
        }
        return FigurePose(points: points)
    }
}
