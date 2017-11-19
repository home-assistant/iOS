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
    if let iconCodes = FontAwesomeKit.FAKMaterialDesignIcons.allIcons() as? [String: String] {
        let fixedIconIdentifier = iconIdentifier.replacingOccurrences(of: ":", with: "-")
        let iconCode = iconCodes[fixedIconIdentifier]
        CLSLogv("Requesting MaterialDesignIcon: Identifier: %@, Fixed Identifier: %@, Width: %f, Height: %f",
                getVaList([iconIdentifier, fixedIconIdentifier, iconWidth, iconHeight]))
        let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(iconWidth))
        theIcon?.addAttribute(NSAttributedStringKey.foregroundColor.rawValue, value: color)
        if let icon = theIcon {
            return icon.image(with: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)))
        } else {
            CLSLogv("Error generating requested icon %@, Width: %f, Height: %f, falling back to mdi-help",
                    getVaList([iconIdentifier, iconWidth, iconHeight]))
            let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCodes["mdi-help"],
                                                                size: CGFloat(iconWidth))
            theIcon?.addAttribute(NSAttributedStringKey.foregroundColor.rawValue, value: color)
            return theIcon!.image(with: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)))
        }
    } else {
        CLSLogv("Error loading Material Design Icons while requesting icon: %@, Width: %f, Height: %f",
                getVaList([iconIdentifier, iconWidth, iconHeight]))
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

func convertToDictionary(text: String) -> [String: Any]? {
    if let data = text.data(using: .utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print(error.localizedDescription)
        }
    }
    return nil
}

func showAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message,
                                  preferredStyle: UIAlertControllerStyle.alert)
    alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertActionStyle.default, handler: nil))
    UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true,
                                                                completion: nil)
}

func setDefaults() {
    Crashlytics.sharedInstance().setObjectValue(prefs.string(forKey: "lastInstalledVersion"),
                                                forKey: "lastInstalledVersion")
    Crashlytics.sharedInstance().setObjectValue(prefs.integer(forKey: "lastInstalledBundleVersion"),
                                                forKey: "lastInstalledBundleVersion")
    Crashlytics.sharedInstance().setObjectValue(prefs.string(forKey: "lastInstalledShortVersion"),
                                                forKey: "lastInstalledShortVersion")
    if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion"),
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString"),
        let stringedShortVersion = shortVersion as? String,
        let stringedBundleVersion = bundleVersion as? String {
        let combined = "\(stringedShortVersion) (\(stringedBundleVersion))"
        prefs.set(stringedBundleVersion, forKey: "lastInstalledBundleVersion")
        prefs.set(stringedShortVersion, forKey: "lastInstalledShortVersion")
        prefs.set(combined, forKey: "lastInstalledVersion")
    }

    if prefs.object(forKey: "openInChrome") == nil && OpenInChromeController().isChromeInstalled() {
        prefs.setValue(true, forKey: "openInChrome")
    }

    if prefs.object(forKey: "confirmBeforeOpeningUrl") == nil {
        prefs.setValue(true, forKey: "confirmBeforeOpeningUrl")
    }

    if prefs.object(forKey: "locationUpdateOnZone") == nil {
        prefs.set(true, forKey: "locationUpdateOnZone")
    }

    if prefs.object(forKey: "locationUpdateOnBackgroundFetch") == nil {
        prefs.set(true, forKey: "locationUpdateOnBackgroundFetch")
    }

    if prefs.object(forKey: "locationUpdateOnSignificant") == nil {
        prefs.set(true, forKey: "locationUpdateOnSignificant")
    }

    if prefs.object(forKey: "locationUpdateOnNotification") == nil {
        prefs.set(true, forKey: "locationUpdateOnNotification")
    }

    prefs.synchronize()
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
