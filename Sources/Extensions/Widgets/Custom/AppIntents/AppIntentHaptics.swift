import Foundation
#if os(watchOS)
import WatchKit
#else
import AudioToolbox
#endif

enum AppIntentHaptics {
    static func notify(_ style: Style = .success) {
        #if os(watchOS)
        // `AudioServicesPlaySystemSound` doesn't exist on watchOS; the Taptic Engine is driven
        // through `WKInterfaceDevice` instead.
        WKInterfaceDevice.current().play(style.watchHapticType)
        #else
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
        #endif
    }

    enum Style {
        case success
        case warning
        case error

        #if os(watchOS)
        var watchHapticType: WKHapticType {
            switch self {
            case .success: return .success
            case .warning: return .notification
            case .error: return .failure
            }
        }
        #endif
    }
}
