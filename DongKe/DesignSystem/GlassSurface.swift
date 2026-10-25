import SwiftUI

struct GlassSurface: ViewModifier {
    var radius: CGFloat
    var tinted = false
    /// 贴住屏幕底边的面板只圆上沿。四角都圆会让人以为它是浮在半空的卡片，
    /// 系统 sheet 在底部是齐边的。
    var bottomRounded = true

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                background
            }
    }

    private var shape: AnyShape {
        if bottomRounded {
            AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            AnyShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: radius,
                    style: .continuous
                )
            )
        }
    }

    @ViewBuilder
    private var background: some View {
        if #available(iOS 26.0, *), !DebugFlags.forcesLegacyGlass {
            shape
                .fill(.clear)
                .glassEffect(
                    tinted ? .regular.tint(Theme.accent(for: colorScheme).opacity(0.55)) : .regular,
                    in: shape
                )
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    GlassEdges(shape: shape, scheme: colorScheme)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct GlassEdges: View {
    let shape: AnyShape
    let scheme: ColorScheme

    var body: some View {
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
                    .stroke(Theme.Glass.stroke(scheme), lineWidth: 0.5)
            }
            .overlay {
                shape
                    .stroke(
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
    func glassSurface(
        radius: CGFloat = Theme.Radius.glassCard,
        tinted: Bool = false,
        bottomRounded: Bool = true
    ) -> some View {
        modifier(GlassSurface(radius: radius, tinted: tinted, bottomRounded: bottomRounded))
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
