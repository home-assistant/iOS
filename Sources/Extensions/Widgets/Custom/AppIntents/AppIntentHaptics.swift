import AudioToolbox
import Foundation

enum AppIntentHaptics {
    private static let peekSystemSound: SystemSoundID = 1520

    static func notify() {
        // Unfortunately this is the only 'haptics' that work with widgets
        // ideally in the future this should use CoreHaptics for a better experience
        AudioServicesPlaySystemSound(peekSystemSound)
    }
}
