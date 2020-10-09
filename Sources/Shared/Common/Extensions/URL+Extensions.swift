//
//  URL+Extensions.swift
//  Shared
//
//  Created by Stephan Vanterpool on 9/2/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

extension URL {
    /// Return true if receiver's host and scheme is equal to `otherURL`
    public func baseIsEqual(to otherURL: URL) -> Bool {
        return host == otherURL.host
        && port == otherURL.port
        && scheme == otherURL.scheme
        && user == otherURL.user
        && password == otherURL.password
    }
}
