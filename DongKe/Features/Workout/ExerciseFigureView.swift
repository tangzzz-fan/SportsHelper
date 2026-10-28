import SwiftUI
import DongKeCore

@MainActor
@Observable
final class FigurePlaybackStore {
    static let shared = FigurePlaybackStore()
    private init() {}
    var playingFigureID: String?
}

struct ExerciseFigureView: View {
    let catalogId: String
    var figureSize: CGSize
    var showsHalo = true
    /// 训练页自动循环播放。动作库列表里仍然是点一下才播——几十个动作同时动没有意义。
    var autoPlays = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback: FigurePlayback
    private let store = FigurePlaybackStore.shared

    private let frameInterval: TimeInterval = 0.8

    init(
        catalogId: String,
        figureSize: CGSize = CGSize(width: 220, height: 260),
        showsHalo: Bool = true,
        autoPlays: Bool = false
    ) {
        self.catalogId = catalogId
        self.figureSize = figureSize
        self.showsHalo = showsHalo
        self.autoPlays = autoPlays
        let figure = FigureLibrary.bundled.figure(for: catalogId)
        _playback = State(initialValue: FigurePlayback(motion: figure.motion, frameCount: figure.frames.count))
    }

    private var figure: ExerciseFigure {
        FigureLibrary.bundled.figure(for: catalogId)
    }

    private var fit: FigureFit {
        FigureFitCalculator.fit(
            bounds: figure.bounds,
            into: FigureSize(width: figureSize.width, height: figureSize.height),
            padding: 8,
            framing: figure.framing
        )
    }

    private var isCloseUp: Bool { figure.framing == .closeUp }

    private var isPlaying: Bool {
        playback.isPlaying && store.playingFigureID == catalogId
    }

    private var isPlaceholder: Bool {
        figure.catalogId == "_generic"
    }

    var body: some View {
        ZStack {
            if showsHalo {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.halo(for: colorScheme), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: figureSize.width * 0.52
                        )
                    )
                    .frame(width: figureSize.width * 1.05, height: figureSize.width * 1.05)
            }

            ZStack {
                ForEach(Array(figure.frames.enumerated()), id: \.offset) { index, frame in
                    Group {
                        if figure.stroked {
                            FigureShape(frame: frame, fit: fit)
                                .stroke(
                                    Color.primary,
                                    style: StrokeStyle(
                                        lineWidth: max(0.9, figureSize.width * 0.0084),
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                        } else {
                            FigureShape(frame: frame, fit: fit)
                                .fill(Color.primary, style: FillStyle(eoFill: true))
                        }
                    }
                    .opacity(index == playback.displayedIndex ? (isPlaceholder ? 0.16 : 1) : 0)
                }
            }
            .frame(width: figureSize.width, height: figureSize.height)
            .animation(.easeInOut(duration: 0.12), value: playback.displayedIndex)

            if isCloseUp {
                CloseUpBrackets()
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    .frame(width: figureSize.width - 6, height: figureSize.height - 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: figureSize.width, height: figureSize.height)
        .contentShape(Rectangle())
        .onTapGesture { togglePlayback() }
        .onAppear(perform: autoPlayIfNeeded)
        .onChange(of: catalogId) { _, _ in
            // @State 不会随 catalogId 重建，换动作时要重新读这一张图的帧数。
            playback = FigurePlayback(motion: figure.motion, frameCount: figure.frames.count)
            autoPlayIfNeeded()
        }
        .onReceive(Timer.publish(every: frameInterval, on: .main, in: .common).autoconnect()) { _ in
            if isPlaying { playback.advance() }
        }
        .onChange(of: store.playingFigureID) { _, newValue in
            if newValue != catalogId, playback.isPlaying { playback.stop() }
        }
        .accessibilityLabel(Text(isCloseUp ? "动作图示（局部特写）" : "动作图示"))
        .accessibilityAddTraits(playback.canPlay ? .isButton : [])
        .accessibilityHint(playback.canPlay ? Text(isPlaying ? "暂停动作演示" : "播放动作演示") : Text(""))
    }

    private func togglePlayback() {
        guard playback.canPlay else { return }
        if isPlaying {
            playback.stop()
            store.playingFigureID = nil
        } else {
            store.playingFigureID = catalogId
            playback.play()
        }
    }

    private func autoPlayIfNeeded() {
        guard autoPlays, reduceMotion == false, playback.canPlay else { return }
        store.playingFigureID = catalogId
        playback.play()
    }
}

/// 局部特写的四角括号：告诉用户"这是放大的细节"，而不是另一张全身图。
private struct CloseUpBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm = min(rect.width, rect.height) * 0.14
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1)
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x + arm * dx, y: corner.y))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + arm * dy))
        }
        return path
    }
}

private struct FigureShape: Shape {
    let frame: FigureFrame
    let fit: FigureFit

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard case let .vector(vectorPath) = frame else { return path }
        for command in vectorPath.commands {
            switch command {
            case let .move(x, y):
                path.move(to: point(x, y))
            case let .line(x, y):
                path.addLine(to: point(x, y))
            case let .cubic(x1, y1, x2, y2, x, y):
                path.addCurve(to: point(x, y), control1: point(x1, y1), control2: point(x2, y2))
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }

    private func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x * fit.scale + fit.offsetX, y: y * fit.scale + fit.offsetY)
    }
}
