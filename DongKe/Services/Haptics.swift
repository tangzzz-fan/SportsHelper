import UIKit
import AudioToolbox

enum Haptics {
    static func restFinished() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlaySystemSound(1057)
    }

    static func setLogged() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
