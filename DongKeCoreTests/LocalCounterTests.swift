import Foundation
import Testing

@testable import DongKeCore

final class MemoryCounterStorage: CounterStorage, @unchecked Sendable {
    private(set) var values: [String: Int] = [:]

    func read(_ key: String) -> Int {
        values[key] ?? 0
    }

    func write(_ value: Int, for key: String) {
        values[key] = value
    }
}

@MainActor
struct LocalCounterTests {
    @Test func startsAtZero() {
        let counters = LocalCounters(storage: MemoryCounterStorage())
        for counter in LocalCounter.allCases {
            #expect(counters.value(counter) == 0)
        }
    }

    @Test func incrementAccumulates() {
        let counters = LocalCounters(storage: MemoryCounterStorage())
        counters.increment(.recordBroken)
        counters.increment(.recordBroken)
        #expect(counters.value(.recordBroken) == 2)
        #expect(counters.value(.checkpointResumed) == 0)
    }

    @Test func eachCounterHasItsOwnKey() {
        let storage = MemoryCounterStorage()
        let counters = LocalCounters(storage: storage)
        counters.increment(.checkpointResumed)
        counters.increment(.microDoseStarted)
        #expect(storage.values.count == 2)
        #expect(counters.value(.checkpointResumed) == 1)
        #expect(counters.value(.microDoseStarted) == 1)
        #expect(counters.value(.microDoseFinished) == 0)
    }

    @Test func keysCarryTheResetPrefix() {
        for counter in LocalCounter.allCases {
            #expect(counter.key.hasPrefix("dk.counter."))
        }
    }

    @Test func snapshotCoversEveryCounterInOrder() {
        let counters = LocalCounters(storage: MemoryCounterStorage())
        counters.increment(.microDoseFinished)
        let snapshot = counters.snapshot
        #expect(snapshot.map(\.counter) == LocalCounter.allCases)
        #expect(snapshot.first { $0.counter == .microDoseFinished }?.value == 1)
    }

    @Test func survivesANewInstanceOnTheSameStorage() {
        let storage = MemoryCounterStorage()
        LocalCounters(storage: storage).increment(.recordBroken)
        let reopened = LocalCounters(storage: storage)
        #expect(reopened.value(.recordBroken) == 1)
    }

    @Test func titlesAreDistinct() {
        let titles = Set(LocalCounter.allCases.map(\.title))
        #expect(titles.count == LocalCounter.allCases.count)
    }
}
