//
//  CoreStrings+Assemble.swift
//  App
//
//  Created by Bruno Pantaleão on 04/01/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation

public extension CoreStrings {
    static func getDomainLocalizedTitle(domain: Domain) -> String {
        let key = "component::\(domain.rawValue)::title"
        return Current.localized.core(key) ?? domain.rawValue
    }

    static func getDomainStateLocalizedTitle(state: String) -> String? {
        let key = "common::state::\(state)"
        return Current.localized.core(key)
    }
}
