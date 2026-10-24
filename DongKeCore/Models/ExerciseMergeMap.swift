import Foundation

public struct ExerciseMergeMap: Equatable, Sendable {
    public static let current = ExerciseMergeMap(redirects: [:])

    private let links: [String: String]
    private let resolved: [String: String]
    private let looping: Set<String>

    public init(redirects: [String: String]) {
        var clean: [String: String] = [:]
        for (from, to) in redirects {
            let source = from.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = to.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !target.isEmpty, source != target else { continue }
            clean[source] = target
        }

        var resolved: [String: String] = [:]
        var looping: Set<String> = []

        for source in clean.keys {
            var visited: Set<String> = [source]
            guard var cursor = clean[source] else { continue }
            while true {
                if visited.contains(cursor) {
                    looping.insert(source)
                    break
                }
                visited.insert(cursor)
                guard let next = clean[cursor] else { break }
                cursor = next
            }
            if !looping.contains(source) {
                resolved[source] = cursor
            }
        }

        self.links = clean
        self.resolved = resolved
        self.looping = looping
    }

    public var count: Int { links.count }

    public var isEmpty: Bool { links.isEmpty }

    public var pairs: [String: String] { links }

    public var cycles: [String] { looping.sorted() }

    public func resolve(_ catalogId: String) -> String {
        resolved[catalogId] ?? catalogId
    }

    public func merging(_ catalogIds: [String]) -> [String] {
        var seen: Set<String> = []
        var output: [String] = []
        for id in catalogIds {
            let key = resolve(id)
            if seen.insert(key).inserted {
                output.append(key)
            }
        }
        return output
    }

    public func danglingTargets(in library: Set<String>) -> [String] {
        resolved.filter { !library.contains($0.value) }.map(\.key).sorted()
    }
}
