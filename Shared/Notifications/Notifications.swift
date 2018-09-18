//
//  Notifications.swift
//  Shared
//
//  Created by Stephan Vanterpool on 9/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

final class Notifications {
    static func installedPushNotificationSounds() -> [String] {
        let fileManager: FileManager = FileManager()

        let libraryPath: URL

        do {
            libraryPath = try fileManager.url(for: .libraryDirectory,
                                              in: FileManager.SearchPathDomainMask.userDomainMask,
                                              appropriateFor: nil,
                                              create: false)
        } catch let error as NSError {
            print("Error when building URL for library directory", error)
            return [String]()
        }

        let librarySoundsPath = libraryPath.appendingPathComponent("Sounds")

        let librarySoundsContents = fileManager.enumerator(at: librarySoundsPath,
                                                           includingPropertiesForKeys: nil,
                                                           options: FileManager.DirectoryEnumerationOptions(),
                                                           errorHandler: nil)!

        var allSounds = [String]()

        for obj in librarySoundsContents.allObjects {
            if let fileUrl = obj as? URL {
                allSounds.append(fileUrl.lastPathComponent)
            }
        }
        return allSounds
    }
}
