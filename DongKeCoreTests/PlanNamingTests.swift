import Testing
import Foundation
@testable import DongKeCore

@Suite("动作命名与用途")
struct PlanNamingTests {
    @Test("库内动作一律用库里的标准名")
    func libraryNameWins() throws {
        let json = try planJSON(catalogId: "dead_bug", name: "死虫式")
        let draft = PlanImportService.parse(json)
        let item = try #require(draft.plan?.days.flatMap { $0.blocks.flatMap(\.items) }.first { $0.catalogId == "dead_bug" })
        #expect(item.name == "死虫")
        #expect(draft.path == .strictJSON)
    }

    @Test("同一动作的三种写法归一到同一个名字")
    func variantsCollapse() throws {
        let names = ["死虫", "死虫式", "Dead Bug"]
        let resolved = try names.map { name in
            let draft = PlanImportService.parse(try planJSON(catalogId: "dead_bug", name: name))
            return draft.plan?.days.flatMap { $0.blocks.flatMap(\.items) }.first { $0.catalogId == "dead_bug" }?.name
        }
        #expect(Set(resolved.compactMap { $0 }) == ["死虫"])
    }

    @Test("库外动作没有标准名，保留原名")
    func customKeepsName() throws {
        let json = try planJSON(catalogId: "custom_pigeon", name: "鸽子式")
        let draft = PlanImportService.parse(json)
        let item = try #require(draft.plan?.days.flatMap { $0.blocks.flatMap(\.items) }.first)
        #expect(item.name == "鸽子式")
    }

    @Test("每个动作都有用途，默认算力量")
    func purposesDefault() {
        for entry in ExerciseLibrary.all {
            #expect(entry.purposes.isEmpty == false, "\(entry.name) 没有用途")
        }
        #expect(ExerciseLibrary.entry(for: "squat")?.purposes == [.strength])
    }

    @Test("跳跃类同时算热身与力量")
    func jumpIsBoth() {
        for id in ["jumping_jack", "high_knees", "mountain_climber"] {
            #expect(ExerciseLibrary.entry(for: id)?.purposes == [.warmup, .strength], "\(id) 用途不对")
        }
    }

    @Test("热身动作池至少三个")
    func warmupPoolNotEmpty() {
        let warmups = ExerciseLibrary.all.filter { $0.purposes.contains(.warmup) }
        #expect(warmups.count >= 3)
    }

    @Test("拉伸动作池至少八个，且都是静态保持")
    func stretchPool() {
        let stretches = ExerciseLibrary.all.filter { $0.purposes.contains(.stretch) }
        #expect(stretches.count >= 8)
        #expect(stretches.allSatisfy { $0.isStatic }, "拉伸都应是静态保持")
    }

    @Test("拉伸动作不标承重部位，避免被安全校验误判")
    func stretchHasNoAffectedParts() {
        for entry in ExerciseLibrary.all where entry.purposes.contains(.stretch) {
            #expect(entry.affectedParts.isEmpty, "\(entry.name) 不该标承重部位")
        }
    }

    @Test("哑铃动作补到七个")
    func dumbbellPool() {
        #expect(ExerciseLibrary.all.filter { $0.equipment == .dumbbell }.count >= 7)
    }

    @Test("推、拉、肩、手臂都有力量动作")
    func upperCoverage() {
        let ids = ["push_up", "dumbbell_row", "shoulder_press",
                   "dumbbell_bench_press", "dumbbell_floor_press", "dumbbell_rdl",
                   "lateral_raise", "biceps_curl"]
        for id in ids {
            #expect(ExerciseLibrary.entry(for: id) != nil, "缺 \(id)")
        }
    }

    private func planJSON(catalogId: String, name: String) throws -> String {
        var plan = PlanGenerator.makePlan(profile: UserProfile(availableWeekdays: [.monday]))
        plan.days = plan.days.map { day in
            var fixedDay = day
            fixedDay.blocks = day.blocks.map { block in
                var fixedBlock = block
                fixedBlock.items = block.items.enumerated().map { offset, item in
                    guard offset == 0 else { return item }
                    var fixed = item
                    fixed.catalogId = catalogId
                    fixed.name = name
                    return fixed
                }
                return fixedBlock
            }
            return fixedDay
        }
        let data = try JSONEncoder().encode(plan)
        return String(decoding: data, as: UTF8.self)
    }
}
