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

        let mdi = MaterialDesignIcons(named: iconIdentifier.normalizingIconString, fallbackIconName: "help")

        return mdi.image(ofSize: CGSize(width: CGFloat(iconWidth), height: CGFloat(iconHeight)), color: color)
    }
}

public extension MaterialDesignIcons {
    init(serversideValueNamed value: String, fallbackIcon: String? = nil) {
        if let fallbackIcon = fallbackIcon {
            self.init(named: value.normalizingIconString, fallbackIconName: fallbackIcon)
        } else {
            self.init(named: value.normalizingIconString)
        }
    }
}

internal extension String {
    var normalizingIconString: String {
        return self
            .replacingOccurrences(of: "mdi:", with: "")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}
