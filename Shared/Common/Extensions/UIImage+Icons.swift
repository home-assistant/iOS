//
//  UIImage+Icons.swift
//  Shared
//
//  Created by Stephan Vanterpool on 9/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//
import Crashlytics
import FontAwesomeKit
import UIKit

extension UIImage {
    public static func iconForIdentifier(_ iconIdentifier: String, iconWidth: Double, iconHeight: Double, color: UIColor) -> UIImage {
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

}
