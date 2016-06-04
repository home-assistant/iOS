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