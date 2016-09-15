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
    CLSLogv("Requesting MaterialDesignIcon %@ %d %d", getVaList([iconIdentifier, iconWidth, iconHeight]))
    let iconCodes = FontAwesomeKit.FAKMaterialDesignIcons.allIcons() as NSDictionary
    let fixedIconIdentifier = iconIdentifier.replacingOccurrences(of: ":", with: "-")
    let iconCode = iconCodes[fixedIconIdentifier] as? String
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

func movePushNotificationSounds() {
    
    let fileManager: FileManager = FileManager()
    
    let libraryPath = try! fileManager.url(for: .libraryDirectory, in: FileManager.SearchPathDomainMask.userDomainMask, appropriateFor: nil, create: false)
    let librarySoundsPath = libraryPath.appendingPathComponent("Sounds")
    let librarySoundsURL = librarySoundsPath as URL
    if try! librarySoundsURL.checkResourceIsReachable() == false {
        print("Creating sounds directory at", librarySoundsPath)
        try! fileManager.createDirectory(at: librarySoundsPath, withIntermediateDirectories: true, attributes: nil)
    }
    
    let documentsPath = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let fileList = try! fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions())
    for file in fileList {
        let finalUrl = librarySoundsPath.appendingPathComponent(file.lastPathComponent)
        print("Moving", file, "to", finalUrl)
        if try! (finalUrl as URL).checkResourceIsReachable() == false {
            print("File already existed, removing it first!")
            try! fileManager.removeItem(at: finalUrl)
        }
        try! fileManager.moveItem(at: file, to: finalUrl)
    }
}

func getSoundList() -> [String] {
    var result:[String] = []
    let fileManager = FileManager.default
    let enumerator:FileManager.DirectoryEnumerator = fileManager.enumerator(atPath: "/System/Library/Audio/UISounds")!
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
    try! fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
    
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
