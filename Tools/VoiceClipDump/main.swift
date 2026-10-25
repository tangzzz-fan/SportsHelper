import Foundation

// 打印音条清单：id <TAB> 文本。渲染脚本按行调用 say。
for phrase in VoiceClipBank.inventory {
    print("\(VoiceClipBank.clipId(for: phrase))\t\(phrase)")
}
