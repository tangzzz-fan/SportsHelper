import Foundation
import SwiftUI

@MainActor
@Observable
final class LargeTextStore {
    static let shared = LargeTextStore()

    static let minimum: DynamicTypeSize = .accessibility2

    private let key = "dk.a11y.largeText"
    private let defaults: UserDefaults

    var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: key)
    }

    func floor(for system: DynamicTypeSize) -> DynamicTypeSize? {
        guard isEnabled, system < Self.minimum else { return nil }
        return Self.minimum
    }
}
