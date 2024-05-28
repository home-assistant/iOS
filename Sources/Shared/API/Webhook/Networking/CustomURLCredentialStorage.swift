//
//  CustomURLCredentialStorage.swift
//  HomeAssistant
//
//  Created by Bruno Pantaleão on 28/05/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation

final class CustomURLCredentialStorage: URLCredentialStorage {
    let exceptions: () -> SecurityExceptions

    init(server: Server) {
        self.exceptions = { server.info.connection.securityExceptions }
        super.init()
    }

    init(exceptions: SecurityExceptions) {
        self.exceptions = { exceptions }
        super.init()
    }

    override func defaultCredential(for space: URLProtectionSpace) -> URLCredential? {
        exceptions().identity?.credential
    }
}
