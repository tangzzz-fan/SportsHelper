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

    @Test("an id outside the whitelist falls back to the generic placeholder")
    func outsideWhitelistFallsBack() {
        let figure = FigureLibrary.bundled.figure(for: "plank_hold_advanced")
        #expect(figure.catalogId == "_generic")
        #expect(figure.motion == .hold)
        #expect(figure.frames.count == 1)
    }

    @Test("all thirty-one whitelist actions are backed by real artwork")
    func whitelistCoverage() {
        let whitelist = [
            "squat", "push_up", "plank", "lunge", "glute_bridge", "dumbbell_row",
            "shoulder_press", "jumping_jack", "dead_bug", "wall_sit", "side_plank",
            "calf_raise", "superman", "crunch", "mountain_climber", "high_knees",
            "bird_dog", "russian_twist",
            "arm_circle", "cat_cow", "quad_stretch",
            "hamstring_stretch", "hip_flexor_stretch", "chest_stretch", "calf_stretch",
            "child_pose", "butterfly", "dumbbell_bench_press", "dumbbell_rdl",
            "lateral_raise", "biceps_curl"
        ]
        for id in whitelist {
            let figure = FigureLibrary.bundled.figure(for: id)
            #expect(figure.catalogId == id, "\(id) fell back to placeholder")
            #expect(figure.frames.count == 3, "\(id) should carry three frames")
            #expect(figure.bounds.isValid, "\(id) bounds invalid")
        }
    }

    @Test("上游素材确实没有的八个动作走占位图，不假装有")
    func unmappedIdsFallBack() {
        let unmapped = [
            "hip_circle", "scapular_circle", "ankle_circle",
            "neck_stretch", "thread_needle", "back_stretch", "dumbbell_floor_press",
            "march_in_place"
        ]
        for id in unmapped {
            #expect(FigureLibrary.bundled.figure(for: id).catalogId == "_generic", "\(id) 不该声称有专属图")
        }
    }

    @Test("isometric holds are declared explicitly, not inferred from duration type")
    func staticHoldsAreExplicit() {
        let holds = ["plank", "wall_sit", "side_plank"]
        for id in holds {
            #expect(FigureLibrary.bundled.figure(for: id).motion == .hold, "\(id) should hold")
        }
        let stretches = [
            "quad_stretch", "hamstring_stretch", "hip_flexor_stretch", "chest_stretch",
            "calf_stretch", "child_pose", "butterfly"
        ]
        for id in stretches {
            #expect(FigureLibrary.bundled.figure(for: id).motion == .hold, "\(id) 是静态拉伸，应保持单帧")
        }
        let dynamicButDurationTyped = ["mountain_climber", "high_knees", "jumping_jack"]
        for id in dynamicButDurationTyped {
            #expect(FigureLibrary.bundled.figure(for: id).motion == .loop, "\(id) should loop")
        }
    }

    @Test("generated dataset holds thirty-six records, all with three frames")
    func generatedDatasetGate() {
        let records = GeneratedFigureData.records
        #expect(records.count == 36)
        #expect(records.filter { $0.catalogId == "_generic" }.count == 1)
        let generic = records.first { $0.catalogId == "_generic" }
        #expect(generic?.frames.count == 1)
        for record in records where record.catalogId != "_generic" {
            #expect(record.frames.count == 3, "\(record.catalogId) frame count")
            #expect(record.bounds.isValid, "\(record.catalogId) bounds")
            for frame in record.frames {
                #expect(frame.hasPrefix("M "), "\(record.catalogId) frame must start with a move")
                #expect(frame.count > 200, "\(record.catalogId) frame looks empty")
            }
        }
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
