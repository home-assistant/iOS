import Foundation
import Intents
import Shared

public class VoiceShortcutsManager {
    public var voiceShortcuts: [INVoiceShortcut] = []

    public init() {
        updateVoiceShortcuts(completion: nil)
    }

    public func voiceShortcut(for identifier: String) -> INVoiceShortcut? {
        voiceShortcuts.first { voiceShortcut -> Bool in
            if let uuid = UUID(uuidString: identifier) {
                return voiceShortcut.identifier == uuid
            }
            return false
        }
    }

    public func updateVoiceShortcuts(completion: (() -> Void)?) {
        INVoiceShortcutCenter.shared.getAllVoiceShortcuts { voiceShortcutsFromCenter, error in
            guard let voiceShortcutsFromCenter else {
                if let error {
                    Current.Log.error("Failed to fetch voice shortcuts with error: \(error)")
                }
                return
            }
            self.voiceShortcuts = voiceShortcutsFromCenter
            if let completion {
                completion()
            }
        }
    }
}
