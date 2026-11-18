import Foundation
import SwiftUI
import DongKeCore

/// 家里的重量档位。存本机，没有账号，也不上报。
/// 第一次遇到负重动作时问一次，之后可以在设置里改。
@MainActor
@Observable
final class LoadRackStore {
    static let shared = LoadRackStore()

    private let rackKey = "dk.load.rack"
    private let askedKey = "dk.load.rackAsked"
    private let defaults: UserDefaults

    private(set) var rack: LoadRack
    private(set) var hasAnswered: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoded = defaults.data(forKey: rackKey)
            .flatMap { try? JSONDecoder().decode(LoadRack.self, from: $0) }
        rack = decoded ?? .step25
        hasAnswered = defaults.bool(forKey: askedKey)
    }

    func save(_ newValue: LoadRack) {
        rack = newValue
        hasAnswered = true
        defaults.set(true, forKey: askedKey)
        if let data = try? JSONEncoder().encode(newValue) {
            defaults.set(data, forKey: rackKey)
        }
    }
}
