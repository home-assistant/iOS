//
//  ListPickerTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 11/4/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//
@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing

struct ListPickerTests {
    @MainActor
    @Test func testLitPickerUI() async throws {
        assertLightDarkSnapshots(of: ListPickerPreview.standard, drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func testLitPickerContentUI() async throws {
        assertLightDarkSnapshots(of: contentView(searchTerm: ""), drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func testLitPickerContentSearchingUI() async throws {
        assertLightDarkSnapshots(of: contentView(searchTerm: "bbbb"), drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func testLitPickerContentNoResultsUI() async throws {
        assertLightDarkSnapshots(of: contentView(searchTerm: "zzzz"), drawHierarchyInKeyWindow: true)
    }

    @MainActor
    private func contentView(searchTerm: String) -> some View {
        ListPickerContentView(
            title: "Title 1",
            selection: .constant(.init(id: "2", title: "aaaa")),
            content: ListPickerPreview.sampleContent,
            searchTerm: searchTerm
        )
    }
}
