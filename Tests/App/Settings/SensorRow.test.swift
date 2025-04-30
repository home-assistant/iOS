//
//  SettingsSensorsTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 30/4/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

@testable import HomeAssistant
@testable import Shared
import Testing
import SwiftUI

struct SensorRowTests {

    @MainActor
    @Test func testRowView() async throws {
        let view = List {
            SensorRow(
                sensor: WebhookSensor(name: "Sensor 1", uniqueID: "1", icon: .abTestingIcon, state: false, unit: nil, entityCategory: nil),
                isEnabled: true
            )
        }
        assertLightDarkSnapshots(of: view)
    }
}
