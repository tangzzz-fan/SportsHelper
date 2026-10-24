import SwiftUI

struct LargeTextFloor: ViewModifier {
    let store: LargeTextStore

    @Environment(\.dynamicTypeSize) private var systemSize

    func body(content: Content) -> some View {
        if let floor = store.floor(for: systemSize) {
            content.dynamicTypeSize(floor)
        } else {
            content
        }
    }
}

extension View {
    func largeTextFloor(_ store: LargeTextStore) -> some View {
        modifier(LargeTextFloor(store: store))
    }
}
