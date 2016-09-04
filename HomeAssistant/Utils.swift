//
//  Utils.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/3/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import FontAwesomeKit
import SystemConfiguration.CaptiveNetwork

func getIconForIdentifier(iconIdentifier: String, iconWidth: Double, iconHeight: Double, color: UIColor) -> UIImage {
    let iconCodes = FontAwesomeKit.FAKMaterialDesignIcons.allIcons() as NSDictionary
    let fixedIconIdentifier = iconIdentifier.stringByReplacingOccurrencesOfString(":", withString: "-")
    let iconCode = iconCodes[fixedIconIdentifier] as? String
    let theIcon = FontAwesomeKit.FAKMaterialDesignIcons(code: iconCode, size: CGFloat(iconWidth))
    theIcon.addAttribute(NSForegroundColorAttributeName, value: color)
    return theIcon.imageWithSize(CGSizeMake(CGFloat(iconWidth), CGFloat(iconHeight)))
}

func colorWithHexString(hexString: String, alpha:CGFloat? = 1.0) -> UIColor {
    
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

func intFromHexString(hexStr: String) -> UInt32 {
    var hexInt: UInt32 = 0
    // Create scanner
    let scanner: NSScanner = NSScanner(string: hexStr)
    // Tell scanner to skip the # character
    scanner.charactersToBeSkipped = NSCharacterSet(charactersInString: "#")
    // Scan hex value
    scanner.scanHexInt(&hexInt)
    return hexInt
}

func getCurrentWifiSSID() -> String {
    var currentSSID = "Unknown"
    let interfaces:CFArray! = CNCopySupportedInterfaces()
    for i in 0..<CFArrayGetCount(interfaces){
        let interfaceName: UnsafePointer<Void> = CFArrayGetValueAtIndex(interfaces, i)
        let rec = unsafeBitCast(interfaceName, AnyObject.self)
        let unsafeInterfaceData = CNCopyCurrentNetworkInfo("\(rec)")
        if unsafeInterfaceData != nil {
            let interfaceData = unsafeInterfaceData! as Dictionary!
            currentSSID = interfaceData["SSID"] as! String
        }
    }
    return currentSSID
}

// Thanks to http://stackoverflow.com/a/35624018/486182
// Must reboot device after installing new push sounds (http://stackoverflow.com/questions/34998278/change-push-notification-sound-file-only-works-after-ios-reboot)

func movePushNotificationSounds() {
    
    let fileManager: NSFileManager = NSFileManager()
    
    let libraryPath = try! fileManager.URLForDirectory(.LibraryDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false)
    let librarySoundsPath = libraryPath.URLByAppendingPathComponent("Sounds")
    if (!librarySoundsPath.checkResourceIsReachableAndReturnError(nil)) {
        print("Creating sounds directory at", librarySoundsPath)
        try! fileManager.createDirectoryAtURL(librarySoundsPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let documentsPath = try! fileManager.URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
    let fileList = try! fileManager.contentsOfDirectoryAtURL(documentsPath, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions())
    for file in fileList {
        let finalUrl = librarySoundsPath.URLByAppendingPathComponent(file.lastPathComponent!)
        print("Moving", file, "to", finalUrl)
        if (finalUrl.checkResourceIsReachableAndReturnError(nil)) {
            print("File already existed, removing it first!")
            try! fileManager.removeItemAtURL(finalUrl)
        }
        try! fileManager.moveItemAtURL(file, toURL: finalUrl)
    }
}

func getSoundList() -> [String] {
    var result:[String] = []
    let fileManager = NSFileManager.defaultManager()
    let enumerator:NSDirectoryEnumerator = fileManager.enumeratorAtPath("/System/Library/Audio/UISounds")!
    for url in enumerator.allObjects {
        result.append(url as! String)
    }
    return result
}

// copy sound file to /Library/Sounds directory, it will be auto detect and played when a push notification arrive
func copyFileToDirectory(fileName:String) {
    let fileManager = NSFileManager.defaultManager()
    
    let libraryDir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.LibraryDirectory, NSSearchPathDomainMask.UserDomainMask, true)
    let directoryPath = "\(libraryDir.first!)/Sounds"
    try! fileManager.createDirectoryAtPath(directoryPath, withIntermediateDirectories: true, attributes: nil)
    
    let systemSoundPath = "/System/Library/Audio/UISounds/New/\(fileName)"
    let notificationSoundPath = "\(directoryPath)/\(fileName)"
    
    let fileExist = fileManager.fileExistsAtPath(notificationSoundPath)
    if (fileExist) {
        try! fileManager.removeItemAtPath(notificationSoundPath)
    }
    try! fileManager.copyItemAtPath(systemSoundPath, toPath: notificationSoundPath)
}

func listAllInstalledPushNotificationSounds() -> [String] {
    let fileManager: NSFileManager = NSFileManager()
    
    let libraryPath = try! fileManager.URLForDirectory(.LibraryDirectory, inDomain: NSSearchPathDomainMask.UserDomainMask, appropriateForURL: nil, create: false)
    let librarySoundsPath = libraryPath.URLByAppendingPathComponent("Sounds")
    
    let librarySoundsContents = fileManager.enumeratorAtURL(librarySoundsPath, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions(), errorHandler: nil)!
    
    var allSounds = [String]()
    
    for obj in librarySoundsContents.allObjects {
        let file = obj as! NSURL
        allSounds.append(file.lastPathComponent!)
    }
    return allSounds
}

extension UIImage{
    func scaledToSize(size: CGSize) -> UIImage{
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        self.drawInRect(CGRectMake(0, 0, size.width, size.height))
        let newImage:UIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}

extension String {
    
    subscript (i: Int) -> Character {
        return self[self.startIndex.advancedBy(i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        let start = startIndex.advancedBy(r.startIndex)
        let end = start.advancedBy(r.endIndex - r.startIndex)
        return self[Range(start ..< end)]
    }
}