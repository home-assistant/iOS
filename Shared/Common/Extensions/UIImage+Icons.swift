//
//  UIImage+Icons.swift
//  Shared
//
//  Created by Stephan Vanterpool on 9/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//
import Iconic
import UIKit

extension UIImage {
    public static func iconForIdentifier(_ iconIdentifier: String, iconWidth: Double,
                                         iconHeight: Double, color: UIColor) -> UIImage {

        MaterialDesignIcons.register()

        var fixedIconIdentifier = iconIdentifier.replacingOccurrences(of: "mdi:", with: "")
        fixedIconIdentifier = fixedIconIdentifier.replacingOccurrences(of: ":", with: "-")
        let mdi = MaterialDesignIcons.init(named: fixedIconIdentifier, fallbackIconName: "help")

        return mdi.image(ofSize: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)), color: color)
    }

}
