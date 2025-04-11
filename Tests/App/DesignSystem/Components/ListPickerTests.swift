//
//  ListPickerTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 11/4/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//
@testable import HomeAssistant
import SnapshotTesting
import Testing

struct ListPickerTests {
    @MainActor
    @Test func testLitPickerUI() async throws {
        assertLightDarkSnapshots(of: ListPickerPreview.standard, drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func testLitPickerContentUI() async throws {
        assertLightDarkSnapshots(of: ListPickerPreview.content, drawHierarchyInKeyWindow: true)
    }
}
