//
//  SiriShortcut.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift
import Intents

@available(iOS 12, *)
class SiriShortcut: Object {
    @objc dynamic var Identifier: String?
    @objc dynamic var InvocationPhrase: String?
    @objc dynamic var Intent: String?
    @objc dynamic var Data: String?
    @objc dynamic var CreatedAt = Date()

    convenience init(intent: String, shortcut: INVoiceShortcut, jsonData: String?) {
        self.init()

        self.Identifier = shortcut.identifier.description
        self.InvocationPhrase = shortcut.invocationPhrase
        self.Intent = intent
        self.Data = jsonData
    }
}
