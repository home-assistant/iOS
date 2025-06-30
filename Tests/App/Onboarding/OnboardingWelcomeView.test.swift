//
//  OnboardingWelcomeViewTests.swift
//  Tests-App
//
//  Created by Bruno Pantaleão on 30/6/25.
//  Copyright © 2025 Home Assistant. All rights reserved.
//

import Testing
import SnapshotTesting
@testable import HomeAssistant
import SwiftUI

struct OnboardingWelcomeViewTests {

    @MainActor @Test func testSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                OnboardingWelcomeView(shouldDismissOnboarding: .constant(false))
                    .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view)
    }

}
