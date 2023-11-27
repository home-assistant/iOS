//
//  Font+Roboto.swift
//  App
//
//  Created by Bruno Pantaleão on 24/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import UIKit

public extension UIFont {
    static func roboto(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        switch weight {
        case .medium:
            return UIFont(name: "Roboto-Medium", size: size)!
        default:
            return UIFont(name: "Roboto-Regular", size: size)!
        }
    }
}
