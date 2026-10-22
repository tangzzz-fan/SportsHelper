import Testing
import Foundation
@testable import DongKeCore

@Suite("FigureLibrary")
struct FigureLibraryTests {

    @Test("bundled library returns three looping frames for squat")
    func squatShape() {
        let figure = FigureLibrary.bundled.figure(for: "squat")
        #expect(figure.catalogId == "squat")
        #expect(figure.motion == .loop)
        #expect(figure.frames.count == 3)
        #expect(figure.bounds.isValid)
    }

    @Test("squat frames carry a non empty vector path")
    func squatPathNotEmpty() {
        let figure = FigureLibrary.bundled.figure(for: "squat")
        for frame in figure.frames {
            guard case let .vector(path) = frame else {
                Issue.record("expected vector frame")
                return
            }
            #expect(path.commands.count > 50)
            #expect(path.commands.contains { command in
                if case .move = command { return true }
                return false
            })
        }
    }

    @Test("unknown catalog id falls back to the generic placeholder")
    func unknownFallsBack() {
        let figure = FigureLibrary.bundled.figure(for: "custom_dragon_flag")
        #expect(figure.catalogId == "_generic")
        #expect(figure.motion == .hold)
        #expect(figure.frames.count == 1)
        #expect(figure.bounds.isValid)
    }

    @Test("an unshipped whitelist action falls back until its asset lands")
    func unshippedFallsBack() {
        let figure = FigureLibrary.bundled.figure(for: "plank")
        #expect(figure.catalogId == "_generic")
        #expect(figure.motion == .hold)
    }
}

@Suite("Figure source contract")
struct FigureSourceContractTests {

    struct TwoFrameRasterSource: FigureSource {
        func figure(for catalogId: String) -> ExerciseFigure? {
            guard catalogId == "squat" else { return nil }
            return ExerciseFigure(
                catalogId: "squat",
                motion: .hold,
                bounds: FigureBounds(minX: 0, minY: 0, width: 400, height: 500),
                frames: [
                    .raster(RasterFrame(resourceName: "squat-0", pixelWidth: 512, pixelHeight: 512)),
                    .raster(RasterFrame(resourceName: "squat-1", pixelWidth: 512, pixelHeight: 512))
                ]
            )
        }
    }

    @Test("a raster source swaps in without touching the caller")
    func rasterSourceSwaps() {
        let library = FigureLibrary(
            source: TwoFrameRasterSource(),
            fallback: FigureLibrary.bundled.figure(for: "_generic")
        )
        let figure = library.figure(for: "squat")
        #expect(figure.frames.count == 2)
        #expect(figure.motion == .hold)
        guard case let .raster(frame) = figure.frames[0] else {
            Issue.record("expected raster frame")
            return
        }
        #expect(frame.resourceName == "squat-0")
    }

    @Test("a raster source still falls back for uncovered ids")
    func rasterSourceFallsBack() {
        let library = FigureLibrary(
            source: TwoFrameRasterSource(),
            fallback: FigureLibrary.bundled.figure(for: "_generic")
        )
        #expect(library.figure(for: "plank").catalogId == "_generic")
    }
}

@Suite("FigureFit")
struct FigureFitTests {

    let bounds = FigureBounds(minX: 100, minY: 200, width: 200, height: 100)

    @Test("wide container is limited by height")
    func wideContainer() {
        let fit = FigureFitCalculator.fit(
            bounds: bounds,
            into: FigureSize(width: 400, height: 120),
            padding: 10
        )
        #expect(abs(fit.scale - 1.0) < 0.0001)
        #expect(abs(fit.offsetX - ((400 - 200) / 2 - 100)) < 0.0001)
        #expect(abs(fit.offsetY - ((120 - 100) / 2 - 200)) < 0.0001)
    }

    @Test("tall container is limited by width")
    func tallContainer() {
        let fit = FigureFitCalculator.fit(
            bounds: bounds,
            into: FigureSize(width: 220, height: 400),
            padding: 10
        )
        #expect(abs(fit.scale - 1.0) < 0.0001)
    }

    @Test("scale keeps the aspect ratio and stays inside the padded box")
    func scaleFitsInsidePaddedBox() {
        let fit = FigureFitCalculator.fit(
            bounds: bounds,
            into: FigureSize(width: 220, height: 260),
            padding: 8
        )
        let scaledWidth = bounds.width * fit.scale
        let scaledHeight = bounds.height * fit.scale
        #expect(scaledWidth <= 220 - 16 + 0.001)
        #expect(scaledHeight <= 260 - 16 + 0.001)
        #expect(abs(scaledWidth / scaledHeight - bounds.width / bounds.height) < 0.0001)
        #expect(abs((fit.offsetX + bounds.minX * fit.scale) - (220 - scaledWidth) / 2) < 0.0001)
        #expect(abs((fit.offsetY + bounds.minY * fit.scale) - (260 - scaledHeight) / 2) < 0.0001)
    }
}
