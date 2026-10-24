import SwiftUI

struct GlassSurface: ViewModifier {
    var radius: CGFloat
    var tinted = false

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                background
            }
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if #available(iOS 26.0, *), !DebugFlags.forcesLegacyGlass {
            shape
                .fill(.clear)
                .glassEffect(
                    tinted ? .regular.tint(Theme.accent(for: colorScheme).opacity(0.55)) : .regular,
                    in: .rect(cornerRadius: radius, style: .continuous)
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    GlassEdges(radius: radius, scheme: colorScheme)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct GlassEdges: View {
    let radius: CGFloat
    let scheme: ColorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(Theme.Glass.fill(scheme))
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0), location: 0),
                                .init(color: .white.opacity(Theme.Glass.sheen(scheme)), location: 0.44),
                                .init(color: .white.opacity(0), location: 0.80)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                shape
                    .strokeBorder(Theme.Glass.stroke(scheme), lineWidth: 0.5)
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Theme.Glass.topEdge(scheme),
                                .clear,
                                .clear,
                                Theme.Glass.bottomEdge(scheme)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
            }
    }
}

extension View {
    func glassSurface(radius: CGFloat = Theme.Radius.glassCard, tinted: Bool = false) -> some View {
        modifier(GlassSurface(radius: radius, tinted: tinted))
    }
}

struct PressableGlassStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

enum DebugFlags {
    static var forcesLegacyGlass: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["DK_FORCE_LEGACY_GLASS"] == "1"
        #else
        false
        #endif
    }
}
