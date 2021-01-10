//
//  UIImage+Icons.swift
//  Shared
//
//  Created by Stephan Vanterpool on 9/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

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
}

public extension MaterialDesignIcons {
    convenience init(serversideValueNamed value: String) {
        self.init(named: value.normalizingIconString)
    }
}

internal extension String {
    var normalizingIconString: String {
        return self
            .replacingOccurrences(of: "mdi:|hass:", with: "", options: .regularExpression)
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}
