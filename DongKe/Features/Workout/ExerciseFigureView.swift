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

    @Environment(\.colorScheme) private var colorScheme
    @State private var playback: FigurePlayback
    private let store = FigurePlaybackStore.shared

    private let frameInterval: TimeInterval = 0.8

    init(catalogId: String, figureSize: CGSize = CGSize(width: 220, height: 260)) {
        self.catalogId = catalogId
        self.figureSize = figureSize
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
            padding: 8
        )
    }

    private var isPlaying: Bool {
        playback.isPlaying && store.playingFigureID == catalogId
    }

    var body: some View {
        ZStack {
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

            ZStack {
                ForEach(Array(figure.frames.enumerated()), id: \.offset) { index, frame in
                    FigureShape(frame: frame, fit: fit)
                        .fill(Color.primary, style: FillStyle(eoFill: true))
                        .opacity(index == playback.displayedIndex ? 1 : 0)
                }
            }
            .frame(width: figureSize.width, height: figureSize.height)
            .animation(.easeInOut(duration: 0.12), value: playback.displayedIndex)
        }
        .frame(width: figureSize.width, height: figureSize.height)
        .contentShape(Rectangle())
        .onTapGesture { togglePlayback() }
        .onReceive(Timer.publish(every: frameInterval, on: .main, in: .common).autoconnect()) { _ in
            if isPlaying { playback.advance() }
        }
        .onChange(of: store.playingFigureID) { _, newValue in
            if newValue != catalogId, playback.isPlaying { playback.stop() }
        }
        .accessibilityLabel(Text("动作图示"))
        .accessibilityAddTraits(playback.canPlay ? .isButton : [])
    }

    private func togglePlayback() {
        guard playback.canPlay else { return }
        if isPlaying {
            playback.stop()
            store.playingFigureID = nil
        } else {
            store.playingFigureID = catalogId
            playback.toggle()
        }
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
