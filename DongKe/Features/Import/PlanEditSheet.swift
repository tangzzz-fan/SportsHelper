import SwiftUI
import UIKit
import DongKeCore

struct EditRowResult {
    var sets: Int
    var value: Int
    var rest: Int
    var catalogId: String?
    var saveAsMine: Bool
    var group: ExerciseGroup
}

struct EditRowSheet: View {
    let row: PlanEditRow
    let myExercises: [UserExercise]
    var onApply: (EditRowResult) -> Void
    var onCancel: () -> Void

    @State private var sets: Int
    @State private var value: Int
    @State private var rest: Int
    @State private var catalogId: String?
    @State private var saveAsMine = false
    @State private var group: ExerciseGroup = .lower

    init(
        row: PlanEditRow,
        myExercises: [UserExercise],
        onApply: @escaping (EditRowResult) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.row = row
        self.myExercises = myExercises
        self.onApply = onApply
        self.onCancel = onCancel
        _sets = State(initialValue: row.sets)
        _value = State(initialValue: row.value)
        _rest = State(initialValue: row.restSec)
        _catalogId = State(initialValue: ExerciseLibrary.entry(for: row.catalogId) == nil ? nil : row.catalogId)
    }

    private var isKnown: Bool {
        ExerciseLibrary.entry(for: row.catalogId) != nil || myExercises.contains { $0.id == row.catalogId }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消", action: onCancel)
                Spacer()
                Text(row.name)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("应用") {
                    onApply(EditRowResult(
                        sets: sets,
                        value: value,
                        rest: rest,
                        catalogId: catalogId,
                        saveAsMine: saveAsMine,
                        group: group
                    ))
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Picker("动作", selection: $catalogId) {
                Text("保留原名「\(row.name)」").tag(String?.none)
                ForEach(ExerciseLibrary.all) { entry in
                    Text("\(entry.name)（\(entry.equipment.chineseName)）").tag(String?.some(entry.id))
                }
                if myExercises.isEmpty == false {
                    Section("我的动作") {
                        ForEach(myExercises) { exercise in
                            Text(exercise.name).tag(String?.some(exercise.id))
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Stepper("组数  \(sets)", value: $sets, in: 1...20)
                .padding(.horizontal, 16)
                .padding(.top, 22)

            Stepper(
                row.isDuration ? "每组 \(value) 秒" : "每组 \(value) 次",
                value: $value,
                in: 1...300
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Stepper("组间休息 \(rest) 秒", value: $rest, in: 0...600, step: 15)
                .padding(.horizontal, 16)
                .padding(.top, 14)

            if isKnown == false {
                Toggle("存为我的动作", isOn: $saveAsMine)
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                if saveAsMine {
                    Picker("归到", selection: $group) {
                        ForEach(ExerciseGroup.allCases, id: \.self) { group in
                            Text(group.title).tag(group)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
            }

            Spacer()
        }
    }
}
