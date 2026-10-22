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
        spec.poses.first ?? FigurePose(points: [:])
    }
}
