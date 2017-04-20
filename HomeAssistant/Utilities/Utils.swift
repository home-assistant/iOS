//
//  Utils.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import FontAwesomeKit
import Crashlytics
import KeychainAccess

func getIconForIdentifier(_ iconIdentifier: String, iconWidth: Double, iconHeight: Double, color: UIColor) -> UIImage {
    if let iconCodes = FontAwesomeKit.FAKMaterialDesignIcons.allIcons() as? [String:String] {
        Crashlytics.sharedInstance().setFloatValue(Float(iconWidth), forKey: "iconWidth")
        Crashlytics.sharedInstance().setFloatValue(Float(iconHeight), forKey: "iconHeight")
        Crashlytics.sharedInstance().setObjectValue(iconIdentifier, forKey: "iconIdentifier")
        let fixedIconIdentifier = iconIdentifier.replacingOccurrences(of: ":", with: "-")
        let iconCode = iconCodes[fixedIconIdentifier]
        if iconIdentifier.contains("mdi") == false || iconCode == nil {
            print("Invalid icon requested", iconIdentifier)
            CLSLogv("Invalid icon requested %@", getVaList([iconIdentifier]))
            let alert = UIAlertController(title: "Invalid icon",
                                          // swiftlint:disable:next line_length
                message: "There is an invalid icon in your configuration. Please search your configuration files for: \(iconIdentifier) and set it to a valid Material Design Icon. Until then, this icon will be a red exclamation point and this alert will continue to display.", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
            let iconCode = iconCodes["mdi-exclamation"]
            let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(iconWidth))
            theIcon?.addAttribute(NSForegroundColorAttributeName, value: colorWithHexString("#ff0000"))
            return theIcon!.image(with: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)))
        }
        CLSLogv("Requesting MaterialDesignIcon: Identifier: %@, Fixed Identifier: %@, Width: %f, Height: %f",
                getVaList([iconIdentifier, fixedIconIdentifier, iconWidth, iconHeight]))
        let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(iconWidth))
        theIcon?.addAttribute(NSForegroundColorAttributeName, value: color)
        return theIcon!.image(with: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)))
    } else {
        return UIImage()
    }
}

func colorWithHexString(_ hexString: String, alpha: CGFloat? = 1.0) -> UIColor {

    // Convert hex string to an integer
    let hexint = Int(intFromHexString(hexString))
    let red = CGFloat((hexint & 0xff0000) >> 16) / 255.0
    let green = CGFloat((hexint & 0xff00) >> 8) / 255.0
    let blue = CGFloat((hexint & 0xff) >> 0) / 255.0
    let alpha = alpha!

    // Create color object, specifying alpha as well
    let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
    return color
}

func intFromHexString(_ hexStr: String) -> UInt32 {
    var hexInt: UInt32 = 0
    // Create scanner
    let scanner: Scanner = Scanner(string: hexStr)
    // Tell scanner to skip the # character
    scanner.charactersToBeSkipped = CharacterSet(charactersIn: "#")
    // Scan hex value
    scanner.scanHexInt32(&hexInt)
    return hexInt
}

// Thanks to http://stackoverflow.com/a/35624018/486182
// Must reboot device after installing new push sounds (http://stackoverflow.com/q/34998278/486182)

// swiftlint:disable:next function_body_length
func movePushNotificationSounds() -> Int {
    var movedFiles = 0

    let fileManager: FileManager = FileManager()

    let libraryPath: URL

    do {
        libraryPath = try fileManager.url(for: .libraryDirectory,
                                          in: FileManager.SearchPathDomainMask.userDomainMask,
                                          appropriateFor: nil, create: false)
    } catch let error as NSError {
        print("Error when building URL for library directory", error)
        return 0
    }

    let librarySoundsPath = libraryPath.appendingPathComponent("Sounds")

    do {
        print("Creating sounds directory at", librarySoundsPath)
        try fileManager.createDirectory(at: librarySoundsPath, withIntermediateDirectories: true, attributes: nil)
    } catch let error as NSError {
        print("Error creating /Library/Sounds directory", error)
        return 0
    }

    let documentsPath: URL

    do {
        documentsPath = try fileManager.url(for: .documentDirectory,
                                            in: .userDomainMask,
                                            appropriateFor: nil,
                                            create: false)
    } catch let error as NSError {
        print("Error building documents path URL", error)
        return 0
    }

    let fileList: [URL]

    do {
        fileList = try fileManager.contentsOfDirectory(at: documentsPath,
                                                       includingPropertiesForKeys: nil,
                                                       options: FileManager.DirectoryEnumerationOptions())
    } catch let error as NSError {
        print("Error getting contents of documents directory", error)
        return 0
    }

    for file in fileList {
        if file.lastPathComponent.contains("realm") {
            continue
        }
        let finalUrl = librarySoundsPath.appendingPathComponent(file.lastPathComponent)
        print("Moving", file, "to", finalUrl)
        do {
            print("Checking for existence of file")
            try fileManager.removeItem(at: finalUrl)
        } catch let rmError as NSError {
            print("Error removing existing file", rmError)
        }
        do {
            try fileManager.moveItem(at: file, to: finalUrl)
            movedFiles += 1
        } catch let error as NSError {
            print("Error when attempting to move files", error)
        }
    }
    return movedFiles
}

func getSoundList() -> [String] {
    var result: [String] = []
    let fileManager = FileManager.default
    let enumerator: FileManager.DirectoryEnumerator = fileManager.enumerator(atPath:
        "/System/Library/Audio/UISounds/New")!
    for url in enumerator.allObjects {
        if let urlString = url as? String {
            result.append(urlString)
        }
    }
    return result
}

// copy sound file to /Library/Sounds directory, it will be auto detect and played when a push notification arrive
func copyFileToDirectory(_ fileName: String) {
    let fileManager = FileManager.default

    let libraryDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory,
                                                         FileManager.SearchPathDomainMask.userDomainMask, true)
    let directoryPath = "\(libraryDir.first!)/Sounds"
    do {
        print("Creating sounds directory at", directoryPath)
        try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
    } catch let error as NSError {
        print("Error creating /Library/Sounds directory", error)
        return
    }

    let systemSoundPath = "/System/Library/Audio/UISounds/New/\(fileName)"
    let notificationSoundPath = "\(directoryPath)/\(fileName)"

    let fileExist = fileManager.fileExists(atPath: notificationSoundPath)
    if fileExist {
        do {
            try fileManager.removeItem(atPath: notificationSoundPath)
        } catch let error as NSError {
            print("Error when attempting to remove item", error)
        }
    }
    do {
        try fileManager.copyItem(atPath: systemSoundPath, toPath: notificationSoundPath)
    } catch let error as NSError {
        print("Error when attempgint to copy item", error)
    }
}

func listAllInstalledPushNotificationSounds() -> [String] {
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

func migrateUserDefaultsToAppGroups() {

    // User Defaults - Old
    let userDefaults = UserDefaults.standard

    // App Groups Default - New
    let groupDefaults = UserDefaults(suiteName: "group.io.robbie.homeassistant")

    // Key to track if we migrated
    let didMigrateToAppGroups = "DidMigrateToAppGroups"

    if let groupDefaults = groupDefaults {
        if !groupDefaults.bool(forKey: didMigrateToAppGroups) {
            for key in userDefaults.dictionaryRepresentation().keys {
                groupDefaults.set(userDefaults.dictionaryRepresentation()[key], forKey: key)
            }
            groupDefaults.set(true, forKey: didMigrateToAppGroups)
            groupDefaults.synchronize()
            print("Successfully migrated defaults")
        } else {
            print("No need to migrate defaults")
        }
    } else {
        print("Unable to create NSUserDefaults with given app group")
    }

}

func migrateSecretsToKeychain() {

    let groupDefaults = UserDefaults(suiteName: "group.io.robbie.homeassistant")

    let didMigrateToKeychain = "DidMigrateSecretsToKeychain"

    if let groupDefaults = groupDefaults {
        if !groupDefaults.bool(forKey: didMigrateToKeychain) {
            keychain["baseURL"] = groupDefaults.string(forKey: "baseURL")
            keychain["apiPassword"] = groupDefaults.string(forKey: "apiPassword")
            groupDefaults.removeObject(forKey: "baseURL")
            groupDefaults.removeObject(forKey: "apiPassword")
            groupDefaults.set(true, forKey: didMigrateToKeychain)
            groupDefaults.synchronize()
            print("Successfully migrated secrets to keychain")
        } else {
            print("No need to migrate secrets")
        }
    } else {
        print("Unable to create NSUserDefaults with given app group")
    }
}

func migrateDeviceIDToKeychain() {

    let groupDefaults = UserDefaults(suiteName: "group.io.robbie.homeassistant")

    let didMigrateToKeychain = "DidMigrateDeviceIDToKeychain"

    if let groupDefaults = groupDefaults {
        if !groupDefaults.bool(forKey: didMigrateToKeychain) {
            keychain["deviceID"] = groupDefaults.string(forKey: "deviceId")
            groupDefaults.removeObject(forKey: "deviceId")
            groupDefaults.set(true, forKey: didMigrateToKeychain)
            groupDefaults.synchronize()
            print("Successfully migrated device ID to keychain")
        } else {
            print("No need to migrate device ID")
        }
    } else {
        print("Unable to create NSUserDefaults with given app group")
    }
}

func resetStores() {
    do {
        try keychain.removeAll()
    } catch {
        print("Error when trying to delete everything from Keychain!")
    }

    if let groupDefaults = UserDefaults(suiteName: "group.io.robbie.homeassistant") {
        for key in groupDefaults.dictionaryRepresentation().keys {
            groupDefaults.removeObject(forKey: key)
        }
        groupDefaults.synchronize()
    }
}

func openURLStringInBrowser(url: String) {
    openURLInBrowser(urlToOpen: URL(string: url)!)
}

func openURLInBrowser(urlToOpen: URL) {
    if OpenInChromeController.sharedInstance.isChromeInstalled() && prefs.bool(forKey: "openInChrome") {
        _ = OpenInChromeController.sharedInstance.openInChrome(urlToOpen, callbackURL: nil)
    } else {
        if #available(iOS 10, *) {
            UIApplication.shared.open(urlToOpen, options: [:], completionHandler: nil)
        } else {
            _ = UIApplication.shared.openURL(urlToOpen)
        }
    }
}

func removeSpecialCharsFromString(text: String) -> String {
    let okayChars: Set<Character> =
        Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890".characters)
    return String(text.characters.filter {okayChars.contains($0) })
}

extension UIImage {
    func scaledToSize(_ size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let newImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension String {

    subscript (i: Int) -> Character {
        return self[self.characters.index(self.startIndex, offsetBy: i)]
    }

    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
}
