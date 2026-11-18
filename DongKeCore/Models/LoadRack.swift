import Foundation

/// 家里的重量是买来的，不是算出来的：可调哑铃只有 2.5kg 一档，固定哑铃只有买到的那几个。
/// 加量提案必须落在买得到的重量上，否则用户拿着「8.8kg」的目标没法执行。
public struct LoadRack: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case adjustable
        case fixed
    }

    public var kind: Kind
    /// 可调档的最小步进；固定档位时不用。
    public var step: Double
    /// 固定档位，从小到大。
    public var plates: [Double]

    public init(kind: Kind, step: Double = 0, plates: [Double] = []) {
        self.kind = kind
        self.step = step
        self.plates = plates.sorted()
    }

    public static let step25 = LoadRack(kind: .adjustable, step: 2.5)
    public static let step5 = LoadRack(kind: .adjustable, step: 5)
    public static let fixedDumbbells = LoadRack(
        kind: .fixed,
        plates: [4, 6, 8, 10, 12, 16, 20, 24]
    )

    /// 比 `current` 大的下一个买得到的重量。没有更重的档位时返回 nil。
    public func next(after current: Double) -> Double? {
        guard current > 0 else { return nil }
        switch kind {
        case .adjustable:
            guard step > 0 else { return nil }
            let steps = (current / step).rounded(.down) + 1
            return steps * step
        case .fixed:
            return plates.first { $0 > current + 0.001 }
        }
    }

    /// 落到最近的可用档位。用户报的重量买不到时，用这个把处方拉回来。
    public func snapped(_ value: Double) -> Double {
        switch kind {
        case .adjustable:
            guard step > 0 else { return value }
            return max(step, (value / step).rounded() * step)
        case .fixed:
            guard plates.isEmpty == false else { return value }
            return plates.min { abs($0 - value) < abs($1 - value) } ?? value
        }
    }

    public var title: String {
        switch kind {
        case .adjustable:
            return step == step.rounded() ? "可调 · 每档 \(Int(step))kg" : "可调 · 每档 \(step)kg"
        case .fixed:
            return "固定档位 · \(plates.count) 档"
        }
    }

    public var detail: String {
        switch kind {
        case .adjustable:
            return "加量时按你的步进往上走，给出买得到的重量。"
        case .fixed:
            let list = plates.map { $0 == $0.rounded() ? "\(Int($0))" : "\($0)" }.joined(separator: " / ")
            return "加量时只在你有的档位里往上走：\(list) kg。"
        }
    }
}
