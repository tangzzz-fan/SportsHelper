import Testing
@testable import DongKeCore

@Suite("音条切分")
struct VoiceClipBankTests {
    @Test("组开始切成四段")
    func setStartSplits() {
        let plan = VoiceClipBank.plan(for: "俯卧撑，第 1 组，共 3 组，10 次")
        #expect(plan == .clips(["俯卧撑", "第 1 组", "共 3 组", "10 次"]))
    }

    @Test("休息切成两段")
    func restSplits() {
        #expect(VoiceClipBank.plan(for: "休息，30 秒") == .clips(["休息", "30 秒"]))
    }

    @Test("跨区块休息按冒号再切，长时长拆成分与秒")
    func blockBreakSplits() {
        let plan = VoiceClipBank.plan(for: "休息，1 分 30 秒，接下来：平板支撑，40 秒")
        #expect(plan == .clips(["休息", "1 分", "30 秒", "接下来", "平板支撑", "40 秒"]))
    }

    @Test("完成句含百分比也能切")
    func finishedSplits() {
        #expect(VoiceClipBank.plan(for: "完成 9 组，完成率 100%") == .clips(["完成 9 组", "完成率 100%"]))
    }

    @Test("倒数就是一个数字")
    func countdownDigit() {
        #expect(VoiceClipBank.plan(for: "3") == .clips(["3"]))
    }

    @Test("主题名在库外，开场句回退")
    func sessionStartFallsBack() {
        #expect(VoiceClipBank.plan(for: "开始训练，上肢与核心，3 个动作，共 9 组") == .fallback)
    }

    @Test("超范围的组数回退")
    func outOfRangeFallsBack() {
        #expect(VoiceClipBank.plan(for: "俯卧撑，第 99 组，共 3 组，10 次") == .fallback)
    }

    @Test("自由文本回退")
    func freeTextFallsBack() {
        #expect(VoiceClipBank.plan(for: "小腹收紧，肋骨别外翻") == .fallback)
    }

    @Test("空串回退")
    func emptyFallsBack() {
        #expect(VoiceClipBank.plan(for: "   ") == .fallback)
    }

    @Test("片段 id 稳定且互不相同")
    func clipIdsAreStable() {
        let a = VoiceClipBank.clipId(for: "俯卧撑")
        #expect(a == VoiceClipBank.clipId(for: "俯卧撑"))
        #expect(a != VoiceClipBank.clipId(for: "臀桥"))
        #expect(a.count == 16)
    }

    @Test("动作库里的名字都能切出来")
    func everyExerciseNameIsCovered() {
        for entry in ExerciseLibrary.all {
            #expect(VoiceClipBank.contains(entry.name), "\(entry.name) 不在音条库里")
        }
    }

    @Test("清单里没有重复项")
    func inventoryHasNoDuplicates() {
        #expect(Set(VoiceClipBank.inventory).count == VoiceClipBank.inventory.count)
    }
}
