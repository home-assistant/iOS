import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: the YAML preview reads `Current.apis`, which the screen evaluates from the main
/// run loop, so the servers and API cache are swapped globally.
@Suite(.sharedState)
@MainActor
struct NotificationActionEditorViewRenderTests {
    private static let category = NotificationCategory(
        identifier: "doorbell",
        serverIdentifier: "server",
        name: "Doorbell"
    )

    @Test func newActionIsValidatedThenSaved() async throws {
        try await withServer {
            var results: [NotificationAction?] = []
            let driver = await SwiftUIScreenDriver.show(
                NotificationActionEditorView(category: Self.category, action: nil) { results.append($0) }
            )
            defer { driver.close() }

            // Nothing filled in: saving shows the validation alert instead.
            await #expect(driver.tapBarButton(titled: L10n.saveLabel))
            await #expect(driver.waitUntil { driver.alert != nil })
            await driver.tapAlertButton()
            #expect(results.isEmpty)

            await driver.type("OPEN_DOOR")
            // Turning everything on reveals the text input rows, which need filling too.
            await driver.toggleSwitches()
            await driver.type("OPEN_DOOR")
            await #expect(driver.tapBarButton(titled: L10n.saveLabel))
            await #expect(driver.waitUntil { !results.isEmpty })

            let saved = try #require(results.first ?? nil)
            #expect(saved.identifier == "OPEN_DOOR")
            #expect(saved.title == "OPEN_DOOR")
            #expect(saved.textInput)
            #expect(saved.textInputButtonTitle == "OPEN_DOOR")
        }
    }

    /// With text input on, an empty button title or an empty placeholder blocks saving. The action's own
    /// title and identifier stay valid, and the same action with both titles saves, so only the text input
    /// checks can reject the first two.
    @Test(arguments: zip(["", "Send", "Send"], ["Message", "", "Message"]))
    func textInputWithoutItsTitlesIsInvalid(buttonTitle: String, placeholder: String) async throws {
        try await withServer {
            var results: [NotificationAction?] = []
            let action = NotificationAction(
                identifier: "REPLY",
                title: "Reply",
                textInput: true,
                textInputButtonTitle: buttonTitle,
                textInputPlaceholder: placeholder
            )
            let driver = await SwiftUIScreenDriver.show(
                NotificationActionEditorView(category: Self.category, action: action) { results.append($0) }
            )
            defer { driver.close() }

            await #expect(driver.tapBarButton(titled: L10n.saveLabel))
            if buttonTitle.isEmpty || placeholder.isEmpty {
                await #expect(driver.waitUntil { driver.alert != nil })
                await driver.tapAlertButton()
                #expect(results.isEmpty)
            } else {
                await #expect(driver.waitUntil { !results.isEmpty })
                let saved = try #require(results.first ?? nil)
                #expect(saved.textInputButtonTitle == buttonTitle)
                #expect(saved.textInputPlaceholder == placeholder)
            }
        }
    }

    @Test func cancellingHandsBackNothing() async throws {
        try await withServer {
            var results: [NotificationAction?] = []
            let action = NotificationAction(identifier: "OK", title: "OK")
            let driver = await SwiftUIScreenDriver.show(
                NotificationActionEditorView(category: Self.category, action: action) { results.append($0) }
            )
            defer { driver.close() }

            await #expect(driver.tapBarButton(titled: L10n.cancelLabel))
            await #expect(driver.waitUntil { results.count == 1 })
            #expect(results.first == .some(nil))
        }
    }

    @Test func serverControlledActionIsReadOnly() async throws {
        try await withServer {
            var action = NotificationAction(identifier: "SERVER", title: "From server", textInput: true)
            action.isServerControlled = true
            let driver = await SwiftUIScreenDriver.show(
                NotificationActionEditorView(category: Self.category, action: action) { _ in }
            )
            defer { driver.close() }
            #expect(driver.sectionCount >= 1)
            await #expect(!driver.tapBarButton(titled: L10n.saveLabel))
        }
    }

    @Test func rendersWithoutAServer() async {
        let previous = Current.servers
        Current.servers = FakeServerManager()
        defer { Current.servers = previous }
        let driver = await SwiftUIScreenDriver.show(
            NotificationActionEditorView(category: Self.category, action: nil) { _ in }
        )
        #expect(driver.sectionCount >= 1)
        driver.close()
    }

    private func withServer(_ body: () async throws -> Void) async throws {
        let previous = Current.servers
        let servers = FakeServerManager(initial: 1)
        let api = HomeAssistantAPI(server: servers.all[0])
        api.connection = HAMockConnection()
        Current.setCachedApi(api, for: servers.all[0].identifier)
        Current.servers = servers
        defer {
            Current.resetAPICache(for: servers.all.map(\.identifier))
            Current.servers = previous
        }
        try await body()
    }
}
