@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing

struct LocalAccessPermissionViewTests {
    @MainActor @Test func testWithoutInitialSelectionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                LocalAccessPermissionView { _ in
                    // Action for testing
                }
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "no-initial-selection")
    }
    
    @MainActor @Test func testWithMostSecureInitialSelectionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                LocalAccessPermissionView(initialSelection: .mostSecure) { _ in
                    // Action for testing
                }
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "most-secure-initial-selection")
    }
    
    @MainActor @Test func testWithLessSecureInitialSelectionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            NavigationView {
                LocalAccessPermissionView(initialSelection: .lessSecure) { _ in
                    // Action for testing
                }
                .toolbarVisibility(.hidden, for: .navigationBar)
            }
        )
        assertLightDarkSnapshots(of: view, named: "less-secure-initial-selection")
    }
}

struct LocalAccessPermissionViewInNavigationViewTests {
    @MainActor @Test func testWithoutInitialSelectionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            LocalAccessPermissionViewInNavigationView { _ in
                // Action for testing
            }
        )
        assertLightDarkSnapshots(of: view, named: "no-initial-selection")
    }
    
    @MainActor @Test func testWithMostSecureInitialSelectionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            LocalAccessPermissionViewInNavigationView(initialSelection: .mostSecure) { _ in
                // Action for testing
            }
        )
        assertLightDarkSnapshots(of: view, named: "most-secure-initial-selection")
    }
    
    @MainActor @Test func testWithLessSecureInitialSelectionSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        let view = AnyView(
            LocalAccessPermissionViewInNavigationView(initialSelection: .lessSecure) { _ in
                // Action for testing
            }
        )
        assertLightDarkSnapshots(of: view, named: "less-secure-initial-selection")
    }
}