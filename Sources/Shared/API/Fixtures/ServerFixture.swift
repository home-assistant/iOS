//
//  ServerFixture.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import Shared

struct ServerFixture {
    static var standard = Server(identifier: "123", getter: {
        .init(
            name: "A Name",
            connection: .init(
                externalURL: nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(exceptions: [])
            ),
            token: .init(
                accessToken: "",
                refreshToken: "",
                expiration: Date()
            ),
            version: "123"
        )
    }, setter: { _ in
        true
    })
}
