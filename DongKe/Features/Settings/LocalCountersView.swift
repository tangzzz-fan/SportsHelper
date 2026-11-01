import SwiftUI
import DongKeCore

struct LocalCountersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private let counters = LocalCounters.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(spacing: 0) {
                        let snapshot = counters.snapshot
                        ForEach(Array(snapshot.enumerated()), id: \.element.counter) { index, item in
                            row(item.counter.title, value: item.value)
                            if index < snapshot.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .glassSurface(radius: Theme.Radius.card)

                    Text("只存在这台手机上，不会上传。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("本机记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") { dismiss() }
                        .foregroundStyle(Theme.accent(for: colorScheme))
                }
            }
        }
    }

    private func row(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(Typography.rowTitle)
            Spacer()
            Text("\(value)")
                .font(Typography.rowTitle)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
    }
}
