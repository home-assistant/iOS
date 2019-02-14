//
//  VoiceShortcutsManager.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import Intents

@available(iOS 12, *)
public class VoiceShortcutsManager {

    public var voiceShortcuts: [INVoiceShortcut] = []

    public init() {
        updateVoiceShortcuts(completion: nil)
    }

    public func voiceShortcut(for identifier: String) -> INVoiceShortcut? {
        return voiceShortcuts.first { (voiceShortcut) -> Bool in
            if let uuid = UUID(uuidString: identifier) {
                return voiceShortcut.identifier == uuid
            }
            return false
        }
    }

    public func updateVoiceShortcuts(completion: (() -> Void)?) {
        INVoiceShortcutCenter.shared.getAllVoiceShortcuts { (voiceShortcutsFromCenter, error) in
            guard let voiceShortcutsFromCenter = voiceShortcutsFromCenter else {
                if let error = error {
                    print("Failed to fetch voice shortcuts with error: \(error.localizedDescription)")
                }
                return
            }
            self.voiceShortcuts = voiceShortcutsFromCenter
            if let completion = completion {
                completion()
            }
        }
    }
}
