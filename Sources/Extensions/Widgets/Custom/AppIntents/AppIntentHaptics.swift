import AudioToolbox
import Foundation

enum AppIntentHaptics {
    // System sound 1520 is the iOS "Peek" sound, providing subtle haptic and audio feedback
    private static let peekSystemSound: SystemSoundID = 1520

    static func notify() {
        // Unfortunately this is the only 'haptics' that work with widgets
        // ideally in the future this should use CoreHaptics for a better experience
        AudioServicesPlaySystemSound(peekSystemSound)
    }
}
