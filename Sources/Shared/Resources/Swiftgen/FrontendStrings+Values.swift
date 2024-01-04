//
//  FrontendStrings+Values.swift
//  App
//
//  Created by Bruno Pantaleão on 04/01/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation

public extension FrontendStrings {
    static func getDefaultStateLocalizedTitle(state: String) -> String? {
        let key = "state::default::\(state)"
        return Current.localized.frontend(key)
    }
}
