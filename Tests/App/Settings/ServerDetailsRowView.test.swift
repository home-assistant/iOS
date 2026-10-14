import Foundation
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import Testing

/// Covers the row at the top of a server's settings: identity on top, the editable details
/// below it as tappable pills, the active URL highlighted, and an Add pill where a URL is missing.
@Suite(.serialized)
@MainActor
struct ServerDetailsRowViewTests {
    private func card(
        internalURL: String?,
        externalURL: String?,
        activeOption: ServerDetailsRowView.EditOption?,
        usesCloud: Bool = false,
        isSyncing: Bool = false,
        showsActions: Bool = true
    ) -> some View {
        List {
            Section {
                row(
                    internalURL: internalURL,
                    externalURL: externalURL,
                    activeOption: activeOption,
                    usesCloud: usesCloud,
                    isSyncing: isSyncing,
                    showsActions: showsActions
                )
            }
        }
    }

    private func row(
        internalURL: String?,
        externalURL: String?,
        activeOption: ServerDetailsRowView.EditOption?,
        usesCloud: Bool,
        isSyncing: Bool,
        showsActions: Bool
    ) -> some View {
        ServerDetailsRowView(
            serverName: "Home",
            userName: "Bruno",
            profilePicture: nil,
            details: [
                .init(option: .deviceName, value: "iPhone", isPlaceholder: true),
                .init(option: .internalURL, value: internalURL, isActive: activeOption == .internalURL),
                .init(
                    option: .externalURL,
                    value: externalURL,
                    isActive: activeOption == .externalURL,
                    symbol: usesCloud ? .icloud : nil
                ),
            ],
            isSyncing: isSyncing,
            transitionNamespace: nil,
            onEdit: { _ in },
            onSync: {},
            onTroubleshoot: {},
            onOpen: {},
            showsActions: showsActions
        )
    }

    private let layout: SwiftUISnapshotLayout = .fixed(width: 390, height: 480)

    @Test func bothURLsOnInternal() async throws {
        assertLightDarkSnapshots(
            of: card(
                internalURL: "http://homeassistant.local:8123",
                externalURL: "https://home.example.com",
                activeOption: .internalURL
            ),
            layout: layout
        )
    }

    @Test func syncing() async throws {
        assertLightDarkSnapshots(
            of: card(
                internalURL: "http://homeassistant.local:8123",
                externalURL: "https://home.example.com",
                activeOption: .internalURL,
                isSyncing: true
            ),
            layout: layout
        )
    }

    @Test func contextMenuPreview() async throws {
        assertLightDarkSnapshots(
            of: card(
                internalURL: "http://homeassistant.local:8123",
                externalURL: "https://home.example.com",
                activeOption: .internalURL,
                showsActions: false
            ),
            layout: layout
        )
    }

    @Test func withoutInternalURL() async throws {
        assertLightDarkSnapshots(
            of: card(internalURL: nil, externalURL: "https://home.example.com", activeOption: .externalURL),
            layout: layout
        )
    }

    @Test func withoutExternalURL() async throws {
        assertLightDarkSnapshots(
            of: card(internalURL: "http://homeassistant.local:8123", externalURL: nil, activeOption: .internalURL),
            layout: layout
        )
    }

    @Test func noActiveURL() async throws {
        assertLightDarkSnapshots(
            of: card(internalURL: "http://homeassistant.local:8123", externalURL: nil, activeOption: nil),
            layout: layout
        )
    }

    @Test func noURLs() async throws {
        assertLightDarkSnapshots(
            of: card(internalURL: nil, externalURL: nil, activeOption: nil),
            layout: layout
        )
    }

    @Test func homeAssistantCloud() async throws {
        assertLightDarkSnapshots(
            of: card(
                internalURL: "http://homeassistant.local:8123",
                externalURL: "Home Assistant Cloud",
                activeOption: .externalURL,
                usesCloud: true
            ),
            layout: layout
        )
    }
}
