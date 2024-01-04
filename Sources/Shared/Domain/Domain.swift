//
//  Domains.swift
//  App
//
//  Created by Bruno Pantaleão on 04/01/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation

public enum Domain: String, CaseIterable {
    case button
    case cover
    case input_boolean
    case input_button
    case light
    case lock
    case scene
    case script
    case `switch`

    public var carPlaySupportedDomains: [Domain] {
        [
            .button,
            .cover,
            .input_boolean,
            .input_button,
            .light,
            .lock,
            .scene,
            .script,
            .switch
        ]
    }

    public var localizedDescription: String {
        CoreStrings.getDomainLocalizedTitle(domain: self)
    }

    public var isCarPlaySupported: Bool {
        carPlaySupportedDomains.contains(self)
    }
}
