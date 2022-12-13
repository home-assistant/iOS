//
//  RequestHandler.swift
//  Extensions-Matter
//
//  Created by Zac West on 2022-12-13.
//  Copyright © 2022 Home Assistant. All rights reserved.
//

import MatterSupport

// The extension is launched in response to `MatterAddDeviceRequest.perform()` and this class is the entry point
// for the extension operations.
@available(iOS 16.1, *)
class RequestHandler: MatterAddDeviceExtensionRequestHandler {
    override func validateDeviceCredential(_ deviceCredential: MatterAddDeviceExtensionRequestHandler.DeviceCredential) async throws {
        // Use this function to perform additional attestation checks if that is useful for your ecosystem.
    }

    override func selectWiFiNetwork(from wifiScanResults: [MatterAddDeviceExtensionRequestHandler.WiFiScanResult]) async throws -> MatterAddDeviceExtensionRequestHandler.WiFiNetworkAssociation {
        return .defaultSystemNetwork
    }

    override func selectThreadNetwork(from threadScanResults: [MatterAddDeviceExtensionRequestHandler.ThreadScanResult]) async throws -> MatterAddDeviceExtensionRequestHandler.ThreadNetworkAssociation {
        return .defaultSystemNetwork
    }

    override func commissionDevice(in home: MatterAddDeviceRequest.Home?, onboardingPayload: String, commissioningID: UUID) async throws {
        
    }

    override func rooms(in home: MatterAddDeviceRequest.Home?) async -> [MatterAddDeviceRequest.Room] {
        return []
    }

    override func configureDevice(named name: String, in room: MatterAddDeviceRequest.Room?) async {
        // Use this function to configure the (now) commissioned device with the given name and room.
    }
}
