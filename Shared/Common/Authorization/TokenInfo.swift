//
//  TokenInfo.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/20/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

public struct TokenInfo {
    let accessToken: String
    let expiration: Date
    let refreshToken: String
    let tokenType: String
}
