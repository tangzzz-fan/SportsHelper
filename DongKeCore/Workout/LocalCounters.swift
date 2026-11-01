import Foundation

public enum LocalCounter: String, CaseIterable, Sendable {
    case checkpointResumed
    case recordBroken
    case microDoseStarted
    case microDoseFinished

    public var key: String { "dk.counter.\(rawValue)" }

    public var title: String {
        switch self {
        case .checkpointResumed: "断点续练"
        case .recordBroken: "破纪录"
        case .microDoseStarted: "三分钟 · 打开"
        case .microDoseFinished: "三分钟 · 做完"
        }
    }
}

public protocol CounterStorage: AnyObject, Sendable {
    func read(_ key: String) -> Int
    func write(_ value: Int, for key: String)
}

public final class UserDefaultsCounterStorage: CounterStorage, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func read(_ key: String) -> Int {
        defaults.integer(forKey: key)
    }

    public func write(_ value: Int, for key: String) {
        defaults.set(value, forKey: key)
    }
}

@MainActor
public final class LocalCounters {
    public static let shared = LocalCounters()

    private let storage: CounterStorage

    public init(storage: CounterStorage = UserDefaultsCounterStorage()) {
        self.storage = storage
    }

    public func increment(_ counter: LocalCounter) {
        storage.write(storage.read(counter.key) + 1, for: counter.key)
    }

    public func value(_ counter: LocalCounter) -> Int {
        storage.read(counter.key)
    }

    public var snapshot: [(counter: LocalCounter, value: Int)] {
        LocalCounter.allCases.map { ($0, value($0)) }
    }
}
