import SwiftUI

enum Typography {
    static let pageTitle = Font.largeTitle.weight(.bold)
    static let actionTitle = Font.title.weight(.semibold)
    static let detailTitle = Font.title2.weight(.semibold)
    static let body = Font.body
    static let buttonLabel = Font.body.weight(.semibold)
    static let rowTitle = Font.callout.weight(.medium)
    static let cardTitle = Font.callout.weight(.semibold)
    static let secondary = Font.subheadline
    static let meta = Font.footnote
    static let micro = Font.caption.weight(.semibold)
    static let capsLabel = Font.caption2.weight(.semibold)
    static let monoInput = Font.subheadline.monospaced()
    static let bigNumber = Font.system(.largeTitle, design: .monospaced, weight: .semibold)
    static let timer = Font.system(size: 88, weight: .light, design: .monospaced)
}
