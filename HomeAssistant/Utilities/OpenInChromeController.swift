// Copyright (c) 2015 Ce Zheng
//
// Copyright 2012, Google Inc.
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

private let googleChromeHTTPScheme: String = "googlechrome:"
private let googleChromeHTTPSScheme: String = "googlechromes:"
private let googleChromeCallbackScheme: String = "googlechrome-x-callback:"
private let characterSet: CharacterSet = CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[]")

private func encodeByAddingPercentEscapes(_ input: String?) -> String {
    if let input = input {
        if let percentEncoded = input.addingPercentEncoding(withAllowedCharacters: characterSet) {
            return percentEncoded
        }
    }
    return ""
}

open class OpenInChromeController {
    public static let sharedInstance = OpenInChromeController()

    open func isChromeInstalled() -> Bool {
        if let simpleURL = URL(string: googleChromeHTTPScheme),
            let callbackURL = URL(string: googleChromeCallbackScheme) {
            return UIApplication.shared.canOpenURL(simpleURL) || UIApplication.shared.canOpenURL(callbackURL)
        }
        return false
    }

    // swiftlint:disable:next cyclomatic_complexity
    open func openInChrome(_ url: URL, callbackURL: URL?, createNewTab: Bool = false) -> Bool {
        if let chromeSimpleURL = URL(string: googleChromeHTTPScheme),
            let chromeCallbackURL = URL(string: googleChromeCallbackScheme) {
            if UIApplication.shared.canOpenURL(chromeCallbackURL) {
                var appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
                // CFBundleDisplayName is an optional key, so we will use CFBundleName if it does not exist
                if appName == nil {
                    appName = Bundle.main.infoDictionary?["CFBundleName"] as? String
                }
                let scheme = url.scheme?.lowercased()
                if scheme == "http" || scheme == "https" {
                    var chromeURLString = String(format: "%@//x-callback-url/open/?x-source=%@&url=%@",
                                                 googleChromeCallbackScheme, encodeByAddingPercentEscapes(appName),
                                                 encodeByAddingPercentEscapes(url.absoluteString))
                    if callbackURL != nil {
                        chromeURLString += String(format: "&x-success=%@",
                                                  encodeByAddingPercentEscapes(callbackURL!.absoluteString))
                    }
                    if createNewTab {
                        chromeURLString += "&create-new-tab"
                    }
                    if let chromeURL = URL(string: chromeURLString) {
                        return UIApplication.shared.openURL(chromeURL)
                    }
                }
            } else if UIApplication.shared.canOpenURL(chromeSimpleURL) {
                let scheme = url.scheme?.lowercased()
                var chromeScheme: String?
                if scheme == "http" {
                    chromeScheme = googleChromeHTTPScheme
                } else if scheme == "https" {
                    chromeScheme = googleChromeHTTPSScheme
                }
                if let chromeScheme = chromeScheme {
                    let absoluteURLString = url.absoluteString
                    let lowerBound = absoluteURLString.range(of: ":")!.lowerBound
                    let chromeURLString = chromeScheme + absoluteURLString.suffix(from: lowerBound)
                    return UIApplication.shared.openURL(URL(string: chromeURLString)!)
                }
            }
        }
        return false
    }
}
