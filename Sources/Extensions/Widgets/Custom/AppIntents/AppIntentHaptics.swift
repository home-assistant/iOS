import AudioToolbox
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AppIntentHaptics {
    // System sound IDs for haptic feedback
    // 1519: Peek (subtle), 1520: Pop (stronger), 1521: Nope (three taps)
    private static let peekSystemSound: SystemSoundID = 1519

    static func notify(_ style: Style = .success) {
        #if os(iOS)
        // Try UIKit haptics first (works in app, not in widget extensions)
        if let generator = createFeedbackGenerator(for: style) {
            generator.prepare()
            generator.impactOccurred()
            return
        }
        #endif

        // Fallback to AudioServices for widget extensions
        let soundId: SystemSoundID = switch style {
        case .success: 1519
        case .warning: 1520
        case .error: 1521
        }
        AudioServicesPlaySystemSound(soundId)
    }

    #if os(iOS)
    private static func createFeedbackGenerator(for style: Style) -> UIImpactFeedbackGenerator? {
        // UIImpactFeedbackGenerator doesn't work in widget extensions
        // This will return nil in extension context
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return nil }

        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = switch style {
        case .success: .light
        case .warning: .medium
        case .error: .heavy
        }
        return UIImpactFeedbackGenerator(style: feedbackStyle)
    }
    #endif

    enum Style {
        case success
        case warning
        case error
    }
}
