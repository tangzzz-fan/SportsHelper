import SwiftUI
import DongKeCore

/// 发送前预览：只读，不能改。改内容要回训练回执那边删行，这里只是让用户知道
/// 「这次 AI 会看到什么」——不看就发，等于默认同意。
struct AIReceiptPreviewSheet: View {
    let text: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("这次会带上的记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") { dismiss() }
                }
            }
        }
    }
}
