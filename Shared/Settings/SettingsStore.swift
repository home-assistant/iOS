//
//  SettingsStore.swift
//  Shared
//
//  Created by Stephan Vanterpool on 8/13/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import KeychainAccess

public struct SettingsStore {
    let keychain = Keychain(service: "io.robbie.homeassistant")

    public var baseURL: URL? {
        get {
            guard let urlString = keychain["baseURL"] else {
                return nil
            }

            return try? urlString.asURL()
        }
        set {
            keychain["baseURL"] = newValue?.absoluteString
        }
    }

    public var tokenInfo: TokenInfo? {
        get {
            guard let tokenData = try? keychain.getData("tokenInfo"),
                let unwrappedData = tokenData else {
                return nil
            }

            return try? JSONDecoder().decode(TokenInfo.self, from: unwrappedData)
        }
        set {
            guard let info = newValue else {
                keychain["tokenInfo"] = nil
                return
            }

            do {
                let data = try JSONEncoder().encode(info)
                try keychain.set(data, key: "tokenInfo")
            } catch {
                assertionFailure("Error while saving token info: \(error)")
            }
        }
    }
}
