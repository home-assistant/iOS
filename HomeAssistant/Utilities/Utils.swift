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

func getIconForIdentifier(_ iconIdentifier: String, iconWidth: Double, iconHeight: Double, color: UIColor) -> UIImage {
    let iconCodes = FontAwesomeKit.FAKMaterialDesignIcons.allIcons() as! [String:String]
    Crashlytics.sharedInstance().setFloatValue(Float(iconWidth), forKey: "iconWidth")
    Crashlytics.sharedInstance().setFloatValue(Float(iconHeight), forKey: "iconHeight")
    Crashlytics.sharedInstance().setObjectValue(iconIdentifier, forKey: "iconIdentifier")
    let fixedIconIdentifier = iconIdentifier.replacingOccurrences(of: ":", with: "-")
    let iconCode = iconCodes[fixedIconIdentifier]
    if iconIdentifier.contains("mdi") == false || iconCode == nil {
        print("Invalid icon requested", iconIdentifier)
        CLSLogv("Invalid icon requested %@", getVaList([iconIdentifier]))
        let alert = UIAlertController(title: "Invalid icon", message: "There is an invalid icon in your configuration. Please search your configuration files for: \(iconIdentifier) and set it to a valid Material Design Icon. Until then, this icon will be a red exclamation point and this alert will continue to display.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        let iconCode = iconCodes["mdi-exclamation"]
        let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(iconWidth))
        theIcon?.addAttribute(NSForegroundColorAttributeName, value: colorWithHexString("#ff0000"))
        return theIcon!.image(with: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)))
    }
    CLSLogv("Requesting MaterialDesignIcon: Identifier: %@, Fixed Identifier: %@, Width: %f, Height: %f", getVaList([iconIdentifier, fixedIconIdentifier, iconWidth, iconHeight]))
    // print("Requesting MaterialDesignIcon Identifier: \(iconIdentifier), Fixed identifier: \(fixedIconIdentifier), Width: \(iconWidth), Height: \(iconHeight)")
    let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(iconWidth))
    theIcon?.addAttribute(NSForegroundColorAttributeName, value: color)
    return theIcon!.image(with: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)))
}

func colorWithHexString(_ hexString: String, alpha:CGFloat? = 1.0) -> UIColor {
    
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
// Must reboot device after installing new push sounds (http://stackoverflow.com/questions/34998278/change-push-notification-sound-file-only-works-after-ios-reboot)

func movePushNotificationSounds() -> Int {
    
    let fileManager: FileManager = FileManager()
    
    let libraryPath = try! fileManager.url(for: .libraryDirectory, in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: false)
    let librarySoundsPath = libraryPath.appendingPathComponent("Sounds")
    
    do {
        print("Creating sounds directory at", librarySoundsPath)
        try fileManager.createDirectory(at: librarySoundsPath, withIntermediateDirectories: true, attributes: nil)
    } catch let error as NSError {
        print("Error creating /Library/Sounds directory", error)
        return 0
    }
    
    let documentsPath = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let fileList = try! fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
    var movedFiles = 0
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
        try! fileManager.moveItem(at: file, to: finalUrl)
        movedFiles = movedFiles+1
    }
    return movedFiles
}

func getSoundList() -> [String] {
    var result:[String] = []
    let fileManager = FileManager.default
    let enumerator:FileManager.DirectoryEnumerator = fileManager.enumerator(atPath: "/System/Library/Audio/UISounds/New")!
    for url in enumerator.allObjects {
        result.append(url as! String)
    }
    return result
}

// copy sound file to /Library/Sounds directory, it will be auto detect and played when a push notification arrive
func copyFileToDirectory(_ fileName:String) {
    let fileManager = FileManager.default
    
    let libraryDir = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
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
    if (fileExist) {
        try! fileManager.removeItem(atPath: notificationSoundPath)
    }
    try! fileManager.copyItem(atPath: systemSoundPath, toPath: notificationSoundPath)
}

func listAllInstalledPushNotificationSounds() -> [String] {
    let fileManager: FileManager = FileManager()
    
    let libraryPath = try! fileManager.url(for: .libraryDirectory, in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: false)
    let librarySoundsPath = libraryPath.appendingPathComponent("Sounds")
    
    let librarySoundsContents = fileManager.enumerator(at: librarySoundsPath, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions(), errorHandler: nil)!
    
    var allSounds = [String]()
    
    for obj in librarySoundsContents.allObjects {
        let file = obj as! URL
        allSounds.append(file.lastPathComponent)
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

func logUserDefaults() {
    
    let userDefaults = UserDefaults.standard
    let groupDefaults = UserDefaults(suiteName: "group.io.robbie.homeassistant")
    
    if let groupDefaults = groupDefaults {
        for key in groupDefaults.dictionaryRepresentation().keys {
            print("groupDefaults \(key): \(groupDefaults.dictionaryRepresentation()[key])")
        }
    } else {
        print("Unable to create NSUserDefaults with given app group")
    }
    
    for key in userDefaults.dictionaryRepresentation().keys {
        print("userDefaults \(key): \(userDefaults.dictionaryRepresentation()[key])")
    }
}

func checkIfIPIsInternal(ipAddress: String) -> Bool {
    let pat = "/(^127\\.)|(^192\\.168\\.)|(^10\\.)|(^172\\.1[6-9]\\.)|(^172\\.2[0-9]\\.)|(^172\\.3[0-1]\\.)|(^::1$)|(^[fF][cCdD])/"
    let regex = try! NSRegularExpression(pattern: pat, options: [])
    let matches = regex.matches(in: ipAddress, options: [], range: NSRange(location: 0, length: ipAddress.characters.count))
    return (matches.count > 0)
}

func openURLInBrowser(url: String) {
    if let urlToOpen = URL(string: url) {
        if (OpenInChromeController.sharedInstance.isChromeInstalled()) {
            _ = OpenInChromeController.sharedInstance.openInChrome(urlToOpen)
        } else {
            if #available(iOS 10, *) {
                UIApplication.shared.open(urlToOpen, options: [:], completionHandler: nil)
            } else {
                _ = UIApplication.shared.openURL(urlToOpen)
            }
        }
    }
}

func removeSpecialCharsFromString(text: String) -> String {
    let okayChars : Set<Character> =
        Set("abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890".characters)
    return String(text.characters.filter {okayChars.contains($0) })
}

extension UIImage{
    func scaledToSize(_ size: CGSize) -> UIImage{
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()!
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
