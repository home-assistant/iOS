//
//  Color+ColorAsset.swift
//  Shared-iOS
//
//  Created by Bruno Pantaleão on 27/11/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 13.0, *)
extension Color {
    static func asset(_ colorAsset: ColorAsset) -> Color {
        Color(colorAsset.name)
    }
}
