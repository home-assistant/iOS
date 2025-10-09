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
    @Published var showHomeNetworkConfiguration = false
    @Published var selection: String? = LocalAccessPermissionOptions.secure.rawValue

    let server: Server

    init(server: Server) {
        self.server = server
    }

    func primaryAction() {
        switch selection {
        case LocalAccessPermissionOptions.secure.rawValue:
            if [.authorizedAlways, .authorizedWhenInUse].contains(Current.location.permissionStatus) {
                // User already gave permission previously to access it's location
                // so we can securely proceed
                showHomeNetworkConfiguration = true
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

    func saveNetworkSSID(_ ssid: String) {
        server.update { info in
            info.connection.internalSSIDs = [ssid]
        }
    }

    func secondaryAction() {
        server.update { info in
            info.connection.internalSSIDs = nil
        }
    }
}
