import SwiftUI
import UIKit
import DongKeCore

/// 回执预览：先给全文，用户可以直接删掉不想外发的行，再复制。
/// 出口只有剪贴板，不联网。
struct ReceiptSheet: View {
    @State private var editable: String
    @Environment(\.dismiss) private var dismiss

    init(text: String) {
        _editable = State(initialValue: text)
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $editable)
                .font(.system(.footnote, design: .monospaced))
                .padding(.horizontal, 8)
                .navigationTitle("训练回执")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("复制") {
                            UIPasteboard.general.string = editable
                            LocalCounters.shared.increment(.receiptCopied)
                            dismiss()
                        }
                        .accessibilityIdentifier(A11y.Summary.receiptCopy)
                    }
                }
        }
        .onAppear {
            LocalCounters.shared.increment(.receiptViewed)
        }
    }
}
