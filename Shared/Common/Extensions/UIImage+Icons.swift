//
//  UIImage+Icons.swift
//  Shared
//
//  Created by Stephan Vanterpool on 9/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//
import Crashlytics
import Iconic
import UIKit

extension UIImage {
    public static func iconForIdentifier(_ iconIdentifier: String, iconWidth: Double,
                                         iconHeight: Double, color: UIColor) -> UIImage {

        MaterialDesignIcon.register()

        var fixedIconIdentifier = iconIdentifier.replacingOccurrences(of: "mdi:", with: "")
        fixedIconIdentifier = fixedIconIdentifier.replacingOccurrences(of: ":", with: "-")
        let mdi = MaterialDesignIcon.init(named: fixedIconIdentifier, fallbackIconName: "help")
        CLSLogv("Requesting MaterialDesignIcon: Identifier: %@, Fixed Identifier: %@, Width: %f, Height: %f",
                getVaList([iconIdentifier, fixedIconIdentifier, iconWidth, iconHeight]))

        return mdi.image(ofSize: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)), color: color)
    }

}
