@testable import HomeAssistant
import SnapshotTesting
import SwiftUI
import Testing
import Shared

struct OnboardingScanningInstanceRowTests {
    
    // MARK: - Basic State Tests
    
    @MainActor @Test func testBasicInstanceRowSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Home Assistant",
                internalURLString: "https://homeassistant.local:8123",
                externalURLString: "https://my-home.duckdns.org:8123",
                internalOrExternalURLString: "https://homeassistant.local:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "basic-instance-row")
    }
    
    @MainActor @Test func testLoadingStateSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Home Assistant",
                internalURLString: "https://homeassistant.local:8123",
                externalURLString: "https://my-home.duckdns.org:8123",
                internalOrExternalURLString: "https://homeassistant.local:8123",
                isLoading: true
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "loading-state")
    }
    
    // MARK: - URL Configuration Tests
    
    @MainActor @Test func testInternalURLOnlySnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Local Home Assistant",
                internalURLString: "https://homeassistant.local:8123",
                externalURLString: nil,
                internalOrExternalURLString: "https://homeassistant.local:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "internal-url-only")
    }
    
    @MainActor @Test func testNoInternalURLSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Remote Home Assistant",
                internalURLString: nil,
                externalURLString: "https://my-home.duckdns.org:8123",
                internalOrExternalURLString: "https://my-home.duckdns.org:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "no-internal-url")
    }
    
    @MainActor @Test func testBothURLsSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Full Setup Home Assistant",
                internalURLString: "https://homeassistant.local:8123",
                externalURLString: "https://my-home.duckdns.org:8123",
                internalOrExternalURLString: "https://homeassistant.local:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "both-urls")
    }
    
    // MARK: - Text Content Variations
    
    @MainActor @Test func testLongNameSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "My Very Long Home Assistant Instance Name That Should Wrap",
                internalURLString: "https://homeassistant.local:8123",
                externalURLString: "https://my-very-long-external-domain-name.duckdns.org:8123",
                internalOrExternalURLString: "https://homeassistant.local:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "long-name")
    }
    
    @MainActor @Test func testLongURLsSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Home Assistant",
                internalURLString: "https://very-long-internal-hostname-that-should-be-truncated.local:8123/with/long/path",
                externalURLString: "https://my-extremely-long-external-domain-name-that-should-definitely-be-truncated.duckdns.org:8123/with/very/long/path/structure",
                internalOrExternalURLString: "https://very-long-internal-hostname-that-should-be-truncated.local:8123/with/long/path",
                isLoading: false
            )
            .padding()
            .frame(maxWidth: 320) // Constrain width to test truncation
        )
        
        assertLightDarkSnapshots(of: view, named: "long-urls")
    }
    
    @MainActor @Test func testShortNameSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "HA",
                internalURLString: "http://192.168.1.100:8123",
                externalURLString: nil,
                internalOrExternalURLString: "http://192.168.1.100:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "short-name")
    }
    
    // MARK: - Loading State Variations
    
    @MainActor @Test func testLoadingWithLongContentSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Long Named Home Assistant Instance",
                internalURLString: "https://very-long-hostname.local:8123",
                externalURLString: "https://long-external-domain.duckdns.org:8123",
                internalOrExternalURLString: "https://very-long-hostname.local:8123",
                isLoading: true
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "loading-with-long-content")
    }
    
    @MainActor @Test func testLoadingWithMinimalContentSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "HA",
                internalURLString: "http://10.0.0.1",
                externalURLString: nil,
                internalOrExternalURLString: "http://10.0.0.1",
                isLoading: true
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "loading-minimal-content")
    }
    
    // MARK: - Edge Cases
    
    @MainActor @Test func testIPAddressURLsSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "IP-based Home Assistant",
                internalURLString: "http://192.168.1.100:8123",
                externalURLString: "https://203.0.113.5:8123",
                internalOrExternalURLString: "http://192.168.1.100:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "ip-address-urls")
    }
    
    @MainActor @Test func testHTTPVsHTTPSSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Mixed Protocol Instance",
                internalURLString: "http://homeassistant.local:8123",
                externalURLString: "https://secure-home.duckdns.org:8123",
                internalOrExternalURLString: "http://homeassistant.local:8123",
                isLoading: false
            )
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "http-vs-https")
    }
    
    // MARK: - List Context Tests
    
    @MainActor @Test func testMultipleInstancesInListSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            VStack(spacing: DesignSystem.Spaces.two) {
                OnboardingScanningInstanceRow(
                    name: "Main Home Assistant",
                    internalURLString: "https://homeassistant.local:8123",
                    externalURLString: "https://main-home.duckdns.org:8123",
                    internalOrExternalURLString: "https://homeassistant.local:8123",
                    isLoading: false
                )
                
                OnboardingScanningInstanceRow(
                    name: "Backup Instance",
                    internalURLString: "http://192.168.1.101:8123",
                    externalURLString: nil,
                    internalOrExternalURLString: "http://192.168.1.101:8123",
                    isLoading: true
                )
                
                OnboardingScanningInstanceRow(
                    name: "Remote Only",
                    internalURLString: nil,
                    externalURLString: "https://remote-home.duckdns.org:8123",
                    internalOrExternalURLString: "https://remote-home.duckdns.org:8123",
                    isLoading: false
                )
            }
            .padding()
        )
        
        assertLightDarkSnapshots(of: view, named: "multiple-instances-list")
    }
}

// MARK: - Integration Tests

extension OnboardingScanningInstanceRowTests {
    
    @MainActor @Test func testAccessibilitySnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Accessible Home Assistant",
                internalURLString: "https://homeassistant.local:8123",
                externalURLString: "https://my-home.duckdns.org:8123",
                internalOrExternalURLString: "https://homeassistant.local:8123",
                isLoading: false
            )
            .padding()
            .environment(\.sizeCategory, .accessibilityExtraLarge)
        )
        
        assertLightDarkSnapshots(of: view, named: "accessibility-large-text")
    }
    
    @MainActor @Test func testConstrainedWidthSnapshot() async throws {
        guard #available(iOS 18.0, *) else {
            assertionFailure("Snapshot tests should only run on iOS 18.0 and later")
            return
        }
        
        let view = AnyView(
            OnboardingScanningInstanceRow(
                name: "Constrained Width Test",
                internalURLString: "https://very-long-hostname.local:8123",
                externalURLString: "https://extremely-long-external-domain.duckdns.org:8123",
                internalOrExternalURLString: "https://very-long-hostname.local:8123",
                isLoading: true
            )
            .padding()
            .frame(width: 280) // Very constrained width
        )
        
        assertLightDarkSnapshots(of: view, named: "constrained-width")
    }
}
