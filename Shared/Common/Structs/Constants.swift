//
//  Constants.swift
//  Shared
//
//  Created by Stephan Vanterpool on 6/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

/// Contains shared constants
public struct Constants {
    /// The Bundle ID used for the AppGroupID
    private static var BundleID: String {
        let baseBundleID = Bundle.main.bundleIdentifier!
        var removeWatchID = baseBundleID.replacingOccurrences(of: ".watchkitapp", with: "")
        removeWatchID = removeWatchID.replacingOccurrences(of: ".watchkitextension", with: "")

        return removeWatchID.lowercased()
    }

    /// The App Group ID used by the app and extensions for sharing data.
    public static var AppGroupID: String {
        print("AppGroupID", "group." + self.BundleID)
        return "group." + self.BundleID
    }
}
