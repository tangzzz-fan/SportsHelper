import Foundation
import SwiftUI

/// 减载周开关。默认开着——周期训练没有减载，第四周必然撞墙。
/// 关掉只影响显示与当次训练，不改计划、不改 `revision`。
@MainActor
@Observable
final class DeloadStore {
    static let shared = DeloadStore()

    private let key = "dk.deload.enabled"
    private let defaults: UserDefaults

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: key) as? Bool ?? true
    }
}
