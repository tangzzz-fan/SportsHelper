import SwiftUI

enum Theme {
    static let tint = Color(red: 14 / 255, green: 124 / 255, blue: 102 / 255)
    static let tintDark = Color(red: 52 / 255, green: 179 / 255, blue: 154 / 255)
    static let haloLight = Color(red: 14 / 255, green: 124 / 255, blue: 102 / 255).opacity(0.16)
    static let haloDark = Color(red: 52 / 255, green: 179 / 255, blue: 154 / 255).opacity(0.18)

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark ? tintDark : tint
    }

    static func halo(for scheme: ColorScheme) -> Color {
        scheme == .dark ? haloDark : haloLight
    }

    enum Glass {
        static func fill(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.14)
        }

        static func stroke(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.25)
        }

        static func innerHighlight(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.28) : Color.white.opacity(0.55)
        }

        static func topEdge(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.white.opacity(0.38) : Color.white.opacity(0.65)
        }

        static func bottomEdge(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? Color.black.opacity(0.50) : Color.black.opacity(0.08)
        }

        static func sheen(_ scheme: ColorScheme) -> Double {
            scheme == .dark ? 0.08 : 0.14
        }
    }

    enum Radius {
        static let control: CGFloat = 10
        static let card: CGFloat = 20
        static let glassSheet: CGFloat = 28
        static let glassCard: CGFloat = 36
        static let glassIsland: CGFloat = 40
    }
}
