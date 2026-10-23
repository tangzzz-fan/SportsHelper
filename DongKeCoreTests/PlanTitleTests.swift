import Testing
@testable import DongKeCore

@Suite("导入标题")
struct PlanTitleTests {
    @Test("标题里的「第」不是单位，不能被清掉")
    func keepsOrdinalInTitle() {
        let draft = PlanImportService.parse("增肌计划 第一周\n周一 深蹲 4组×12次")
        #expect(draft.plan?.meta.title == "增肌计划 第一周")
    }

    @Test("标题里的数字要留着")
    func keepsDigitsInTitle() {
        let draft = PlanImportService.parse("8 周增肌 · 第 1 周\n周一 深蹲 4组×12次")
        #expect(draft.plan?.meta.title == "8 周增肌 · 第 1 周")
    }

    @Test("带剂量的第一行不是标题")
    func doseLineIsNotTitle() {
        let draft = PlanImportService.parse("深蹲 4组×12次\n周一 卧推 3组×10次")
        #expect(draft.plan?.meta.title != "深蹲 4组×12次")
    }
}
