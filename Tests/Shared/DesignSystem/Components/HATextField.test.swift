//
//  HATextFieldTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 8/7/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Testing
import SwiftUI
@testable import Shared

struct HATextFieldTests {

    @MainActor @Test func testSnapshot() async throws {
        let view = AnyView(
            VStack(spacing: DesignSystem.Spaces.two) {
                HATextField(placeholder: "Placeholder", text: .constant(""))
                HATextField(placeholder: "Placeholder", text: .constant("123"))
                HATextField(placeholder: "Placeholder", text: .constant("https://bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.com"))
            }
            .padding()
        )
        assertLightDarkSnapshots(of: view)
    }
}
