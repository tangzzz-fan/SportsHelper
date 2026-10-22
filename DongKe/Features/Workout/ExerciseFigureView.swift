import SwiftUI
import DongKeCore

struct ExerciseFigureView: View {
    let catalogId: String
    var figureSize = CGSize(width: 220, height: 260)

    @Environment(\.colorScheme) private var colorScheme

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

            FigureShape(frames: figure.frames, fit: fit, size: figureSize)
                .fill(Color.primary, style: FillStyle(eoFill: true))
                .frame(width: figureSize.width, height: figureSize.height)
        }
        .frame(width: figureSize.width, height: figureSize.height)
        .accessibilityLabel(Text("动作图示"))
    }
}

private struct FigureShape: Shape {
    let frames: [FigureFrame]
    let fit: FigureFit
    let size: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = frames.first else { return path }
        switch first {
        case let .vector(vectorPath):
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
        case .raster:
            break
        }
        return path
    }

    private func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x * fit.scale + fit.offsetX, y: y * fit.scale + fit.offsetY)
    }
}
