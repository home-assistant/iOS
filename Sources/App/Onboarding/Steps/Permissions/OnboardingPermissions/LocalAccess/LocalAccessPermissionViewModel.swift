//
//  LocalAccessPermissionViewModel.swift
//  App
//
//  Created by Bruno Pantaleão on 9/10/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Foundation
import Shared

final class LocalAccessPermissionViewModel: ObservableObject {
    @Published var shouldComplete = false
    @Published var selection: String? = LocalAccessPermissionOptions.secure.rawValue

    func primaryAction() {
        switch selection {
        case LocalAccessPermissionOptions.secure.rawValue:
            if [.authorizedAlways, .authorizedWhenInUse].contains(Current.location.permissionStatus) {
                // User already gave permission previously to access it's location
                // so we can securely proceed
                shouldComplete = true
            } else {
                // TODO: request user location permission
            }
        case LocalAccessPermissionOptions.lessSecure.rawValue:
            // TODO: Show warning
            break
        default:
            assertionFailure("Non-mapped selection")
        }
    }

    func secondaryAction() {
        // TODO: Show warning
    }
}
