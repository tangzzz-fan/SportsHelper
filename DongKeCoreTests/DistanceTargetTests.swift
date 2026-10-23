import Foundation
import Testing
@testable import DongKeCore

@Suite("距离型目标")
struct DistanceTargetTests {
    @Test("公里换算成米")
    func parsesKilometers() throws {
        let item = try #require(DraftLineScanner.parseItem("跑 5 公里"))
        #expect(item.targetType == .distanceM)
        #expect(item.value == 5000)
        #expect(item.rawName == "跑")
    }

    @Test("小数公里")
    func parsesDecimalKilometers() throws {
        let item = try #require(DraftLineScanner.parseItem("跑 1.5 公里"))
        #expect(item.targetType == .distanceM)
        #expect(item.value == 1500)
    }

    @Test("米与 km 缩写")
    func parsesMetersAndAbbreviation() throws {
        let meters = try #require(DraftLineScanner.parseItem("划船 800 米"))
        #expect(meters.targetType == .distanceM)
        #expect(meters.value == 800)

        let shorthand = try #require(DraftLineScanner.parseItem("跑 3km"))
        #expect(shorthand.targetType == .distanceM)
        #expect(shorthand.value == 3000)
    }

    @Test("距离不会被当成次数")
    func distanceIsNotReps() throws {
        let item = try #require(DraftLineScanner.parseItem("跑 5 公里"))
        #expect(item.targetType != .reps)
    }

    @Test("剂量文案按量级切换单位")
    func doseTextSwitchesUnit() {
        #expect(SetTarget(type: .distanceM, value: 800, perSide: false).doseText == "800 米")
        #expect(SetTarget(type: .distanceM, value: 5000, perSide: false).doseText == "5 公里")
        #expect(SetTarget(type: .distanceM, value: 1500, perSide: false).doseText == "1.5 公里")
        #expect(SetTarget(type: .reps, value: 12, perSide: false).doseText == "12 次")
        #expect(SetTarget(type: .durationSec, value: 45, perSide: false).doseText == "45 秒")
    }

    @Test("距离的耗时估算按每米 0.4 秒")
    func estimatedSecondsForDistance() {
        #expect(SetTarget(type: .distanceM, value: 5000, perSide: false).estimatedWorkSeconds == 2000)
        #expect(SetTarget(type: .reps, value: 10, perSide: false).estimatedWorkSeconds == 30)
        #expect(SetTarget(type: .durationSec, value: 45, perSide: false).estimatedWorkSeconds == 45)
    }
}
