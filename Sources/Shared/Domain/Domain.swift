//
//  Domains.swift
//  App
//
//  Created by Bruno Pantaleão on 04/01/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import UIKit

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

    public var icon: UIImage {
        var image = MaterialDesignIcons.bookmarkIcon
        switch self {
        case .button:
            image = MaterialDesignIcons.gestureTapButtonIcon
        case .cover:
            image = MaterialDesignIcons.curtainsIcon
        case .input_boolean:
            image = MaterialDesignIcons.toggleSwitchOutlineIcon
        case .input_button:
            image = MaterialDesignIcons.gestureTapButtonIcon
        case .light:
            image = MaterialDesignIcons.lightbulbIcon
        case .lock:
            image = MaterialDesignIcons.lockIcon
        case .scene:
            image = MaterialDesignIcons.paletteOutlineIcon
        case .script:
            image = MaterialDesignIcons.scriptTextOutlineIcon
        case .switch:
            image = MaterialDesignIcons.lightSwitchIcon
        }
        return image.image(ofSize: .init(width: 64, height: 64), color: .white)
    }

    public var localizedDescription: String {
        CoreStrings.getDomainLocalizedTitle(domain: self)
    }

    public var isCarPlaySupported: Bool {
        carPlaySupportedDomains.contains(self)
    }
}
