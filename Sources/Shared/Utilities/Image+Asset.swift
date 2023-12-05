//
//  Image+Asset.swift
//  Shared-iOS
//
//  Created by Bruno Pantaleão on 04/12/2023.
//  Copyright © 2023 Home Assistant. All rights reserved.
//

import Foundation
import SwiftUI

@available(iOS 13.0, *)
public extension Image {
    init(asset: ImageAsset) {
        self.init(asset.name, bundle: Bundle(for: SettingsStore.self))
    }
}
