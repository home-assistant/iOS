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
        var removeBundleSuffix = baseBundleID.replacingOccurrences(of: ".watchkitapp", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".watchkitextension", with: "")
        removeBundleSuffix = removeBundleSuffix.replacingOccurrences(of: ".TodayWidget", with: "")

        return removeBundleSuffix.lowercased()
    }

    /// The App Group ID used by the app and extensions for sharing data.
    public static var AppGroupID: String {
        print("AppGroupID", "group." + self.BundleID)
        return "group." + self.BundleID
    }
}
