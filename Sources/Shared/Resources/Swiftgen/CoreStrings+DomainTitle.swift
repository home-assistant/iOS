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
        let format = Current.localized.string("component::\(domain.rawValue)::title", "Core")
        return String(format: format, locale: Locale.current, arguments: [])
    }
}
