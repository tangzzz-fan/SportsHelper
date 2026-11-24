import SwiftUI

/// Watch 侧的品牌色。
///
/// 不放进 asset catalog：那会连带要求一份 watchOS 专用的 `AppIcon`
/// （表盘上是圆形的，尺寸和 iPhone 那套不一样），属于发布准备的事，
/// 不该为了一个按钮颜色现在就欠下图标债。取值与 iPhone 的
/// `Theme.tintDark` 一致，深色表盘上够亮。
enum WatchTheme {
    static let accent = Color(red: 52 / 255, green: 179 / 255, blue: 154 / 255)
}
