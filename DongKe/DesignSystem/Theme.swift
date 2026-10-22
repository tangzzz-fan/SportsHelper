import SwiftUI

enum Theme {
    static let tint = Color(red: 14 / 255, green: 124 / 255, blue: 102 / 255)
    static let tintDark = Color(red: 52 / 255, green: 179 / 255, blue: 154 / 255)
    static let haloLight = Color(red: 14 / 255, green: 124 / 255, blue: 102 / 255).opacity(0.16)
    static let haloDark = Color(red: 52 / 255, green: 179 / 255, blue: 154 / 255).opacity(0.18)

    static var accent: Color { tint }

    static func halo(for scheme: ColorScheme) -> Color {
        scheme == .dark ? haloDark : haloLight
    }

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? tintDark : tint
    }
}
