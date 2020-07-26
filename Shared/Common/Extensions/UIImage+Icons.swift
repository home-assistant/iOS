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
    public convenience init(size: CGSize, color: UIColor) {
        // why is UIGraphicsImageRenderer not available on watchOS?
        var alpha: CGFloat = 1
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)

        UIGraphicsBeginImageContextWithOptions(size, alpha == 1.0, 0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        self.init(cgImage: image.cgImage!, scale: image.scale, orientation: image.imageOrientation)
    }

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
