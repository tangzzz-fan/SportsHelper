import SwiftUI
import DongKeCore

struct HealthNoticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private struct NoticeSection: Identifiable {
        let id: String
        let title: String
        let body: String
    }

    private var sections: [NoticeSection] {
        [
            NoticeSection(
                id: "medical",
                title: "这不能替代医生",
                body: "App 里的计划、动作要点和提示都来自通用训练常识，不针对任何人的病史、用药或检查结果。它是帮你把训练排下去的日程工具，不是诊断或治疗方案。"
            ),
            NoticeSection(
                id: "stop",
                title: "什么时候该停",
                body: "出现下列任一情况，当天就停，别硬练：关节刺痛（不是酸胀）、疼痛在动作中加重、手臂或腿发麻、头晕、胸闷、恶心。持续两天以上不缓解，去看医生。"
            ),
            NoticeSection(
                id: "ai",
                title: "机器写的东西可能有错",
                body: "AI 生成和粘贴导入的计划，都是把一段文字整理成动作清单。它可能写错动作名、算错组数时长、把不同动作混成一个，也可能完全忽略你提过的旧伤。保存前逐条看一遍，练的时候觉得不对就改——它是草稿，不是医嘱。"
            ),
            NoticeSection(
                id: "self",
                title: "判断标准在你自己身上",
                body: "同样的计划，别人练完没事，你可能不合适。动作幅度、组数、负重都以「做完不痛、第二天不影响日常」为准。做不动就点「这组做不动」，它只改这一组，不算失败。"
            ),
            NoticeSection(
                id: "data",
                title: "数据在你自己手里",
                body: "档案、计划和打卡记录只存在这台设备上，App 没有账号系统。唯一的网络请求是你主动触发的 AI 生成，走你自己填的接口。设置里可以随时一键清空全部数据。"
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(PlanSafetyChecker.disclaimer)
                        .font(Typography.body)
                        .foregroundStyle(Theme.accent(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(Typography.cardTitle)
                            Text(section.body)
                                .font(Typography.secondary)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("健康提示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier(A11y.Settings.healthNotice)
    }
}
