import Foundation

public enum FigureMotion: String, Codable, Equatable, Sendable {
    case loop
    case hold
}

public struct FigureBounds: Codable, Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var width: Double
    public var height: Double

    public init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }

    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }

    public var isValid: Bool {
        width > 0 && height > 0
            && minX.isFinite && minY.isFinite && width.isFinite && height.isFinite
    }
}

public enum VectorCommand: Equatable, Sendable {
    case move(Double, Double)
    case line(Double, Double)
    case cubic(Double, Double, Double, Double, Double, Double)
    case close
}

public struct VectorPath: Equatable, Sendable {
    public var commands: [VectorCommand]

    public init(commands: [VectorCommand]) {
        self.commands = commands
    }

    public init(dsl: String) {
        self.commands = VectorPath.parse(dsl)
    }

    static func parse(_ dsl: String) -> [VectorCommand] {
        var out: [VectorCommand] = []
        var pending: Character?
        var numbers: [Double] = []

        func flush() {
            guard let cmd = pending else { return }
            var index = 0
            switch cmd {
            case "M":
                while index + 2 <= numbers.count {
                    out.append(.move(numbers[index], numbers[index + 1]))
                    index += 2
                }
            case "L":
                while index + 2 <= numbers.count {
                    out.append(.line(numbers[index], numbers[index + 1]))
                    index += 2
                }
            case "C":
                while index + 6 <= numbers.count {
                    out.append(.cubic(numbers[index], numbers[index + 1],
                                      numbers[index + 2], numbers[index + 3],
                                      numbers[index + 4], numbers[index + 5]))
                    index += 6
                }
            case "Z":
                out.append(.close)
            default:
                break
            }
            numbers.removeAll(keepingCapacity: true)
        }

        for token in dsl.split(separator: " ") {
            if let head = token.first, head.isLetter, token.count == 1 {
                flush()
                pending = head
            } else if let value = Double(token) {
                numbers.append(value)
            }
        }
        flush()
        return out
    }
}

public struct RasterFrame: Equatable, Sendable {
    public var resourceName: String
    public var pixelWidth: Int
    public var pixelHeight: Int

    public init(resourceName: String, pixelWidth: Int, pixelHeight: Int) {
        self.resourceName = resourceName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public enum FigureFrame: Equatable, Sendable {
    case vector(VectorPath)
    case raster(RasterFrame)
}

public struct ExerciseFigure: Equatable, Sendable {
    public var catalogId: String
    public var motion: FigureMotion
    public var bounds: FigureBounds
    public var frames: [FigureFrame]
    public var stroked: Bool

    public init(
        catalogId: String,
        motion: FigureMotion,
        bounds: FigureBounds,
        frames: [FigureFrame],
        stroked: Bool = false
    ) {
        self.catalogId = catalogId
        self.motion = motion
        self.bounds = bounds
        self.frames = frames
        self.stroked = stroked
    }
}

public protocol FigureSource: Sendable {
    func figure(for catalogId: String) -> ExerciseFigure?
}

public struct FigureLibrary: Sendable {
    private let source: any FigureSource
    private let fallback: ExerciseFigure

    public init(source: any FigureSource, fallback: ExerciseFigure) {
        self.source = source
        self.fallback = fallback
    }

    public func figure(for catalogId: String, merging map: ExerciseMergeMap = .current) -> ExerciseFigure {
        source.figure(for: map.resolve(catalogId)) ?? fallback
    }

    public static let bundled = FigureLibrary(source: BundledVectorFigures(), fallback: BundledVectorFigures.generic)
}

public extension FigureLibrary {
    func hasArtwork(for catalogId: String, merging map: ExerciseMergeMap = .current) -> Bool {
        figure(for: catalogId, merging: map).catalogId != BundledVectorFigures.generic.catalogId
    }
}

public struct FigureSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct FigureFit: Equatable, Sendable {
    public var scale: Double
    public var offsetX: Double
    public var offsetY: Double

    public init(scale: Double, offsetX: Double, offsetY: Double) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

public enum FigureFitCalculator {
    public static func fit(bounds: FigureBounds, into size: FigureSize, padding: Double = 8) -> FigureFit {
        let availableWidth = max(1, size.width - 2 * padding)
        let availableHeight = max(1, size.height - 2 * padding)
        let scale = min(availableWidth / bounds.width, availableHeight / bounds.height)
        let scaledWidth = bounds.width * scale
        let scaledHeight = bounds.height * scale
        return FigureFit(
            scale: scale,
            offsetX: (size.width - scaledWidth) / 2 - bounds.minX * scale,
            offsetY: (size.height - scaledHeight) / 2 - bounds.minY * scale
        )
    }
}

struct FigureRecord: Sendable {
    var catalogId: String
    var motion: FigureMotion
    var bounds: FigureBounds
    var frames: [String]
    var stroked: Bool = false
}

struct BundledVectorFigures: FigureSource {
    static let records: [FigureRecord] = GeneratedFigureData.records

    static let generic: ExerciseFigure = {
        guard let record = records.first(where: { $0.catalogId == "_generic" }) else {
            return ExerciseFigure(
                catalogId: "_generic",
                motion: .hold,
                bounds: FigureBounds(minX: 0, minY: 0, width: 1, height: 1),
                frames: []
            )
        }
        return record.makeFigure()
    }()

    private static let figures: [String: ExerciseFigure] = Dictionary(
        uniqueKeysWithValues: records.map { ($0.catalogId, $0.makeFigure()) }
    )

    func figure(for catalogId: String) -> ExerciseFigure? {
        BundledVectorFigures.figures[catalogId]
    }
}

extension FigureRecord {
    func makeFigure() -> ExerciseFigure {
        ExerciseFigure(
            catalogId: catalogId,
            motion: motion,
            bounds: bounds,
            frames: frames.map { FigureFrame.vector(VectorPath(dsl: $0)) },
            stroked: stroked
        )
    }
}
