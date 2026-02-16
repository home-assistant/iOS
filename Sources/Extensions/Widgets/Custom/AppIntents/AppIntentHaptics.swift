import AudioToolbox
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AppIntentHaptics {
    static func notify(_ style: Style = .success) {
        // Widget extensions can only handle haptics from AudioServicesPlaySystemSound
        let soundId: SystemSoundID = switch style {
        case .success:
            // Peek (subtle)
            1519
        case .warning:
            // Pop (stronger)
            1520
        case .error:
            // Nope (three taps)
            1521
        }
        AudioServicesPlaySystemSound(soundId)
    }

    enum Style {
        case success
        case warning
        case error
    }
}
