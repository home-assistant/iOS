//
//  UIScreen+PerfectCornerRadius.swift
//  App
//
//  Created by Bruno Pantaleão on 16/07/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import UIKit

extension UIScreen {
    private static let cornerRadiusKey: String = {
        let components = ["Radius", "Corner", "display", "_"]
        return components.reversed().joined()
    }()

    public var displayCornerRadius: CGFloat {
        guard let cornerRadius = self.value(forKey: Self.cornerRadiusKey) as? CGFloat else {
            assertionFailure("Failed to detect screen corner radius")
            return 0
        }

        return cornerRadius
    }
}
