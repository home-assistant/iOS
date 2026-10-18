@testable import HomeAssistant
import Shared
import Testing

struct FrontendThemeCaptureMessageTests {
    private let capturedAt = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func decodesEveryReportedProperty() throws {
        let message = try #require(makeMessage(body: [
            "themeName": "My Theme",
            "darkMode": false,
            "variables": [
                ["name": "--primary-color", "value": "rgb(3, 169, 244)", "color": "rgb(3, 169, 244)"],
                ["name": "--ha-card-border-radius", "value": "12px", "color": NSNull()],
            ],
        ]))

        #expect(message.appearance == .light)
        #expect(message.variables.count == 2)

        let color = try #require(message.variables.first { $0.name == "--primary-color" })
        #expect(color.serverId == "server-1")
        #expect(color.value == "rgb(3, 169, 244)")
        #expect(color.colorValue == "rgb(3, 169, 244)")
        #expect(color.themeName == "My Theme")
        #expect(color.updatedAt == capturedAt)

        // A property that is not a colour still gets a row, so lengths and fonts survive too.
        let radius = try #require(message.variables.first { $0.name == "--ha-card-border-radius" })
        #expect(radius.value == "12px")
        #expect(radius.colorValue == nil)
    }

    /// The frontend's own flag wins over the system appearance: a user can pin the frontend to dark
    /// while the device is in light mode, and the capture belongs to the appearance it was resolved in.
    @Test func prefersTheFrontendsDarkModeFlagOverTheFallback() throws {
        let message = try #require(makeMessage(
            body: ["darkMode": true, "variables": [["name": "--primary-color", "value": "rgb(0, 0, 0)"]]],
            fallbackAppearance: .light
        ))

        #expect(message.appearance == .dark)
        #expect(message.variables.allSatisfy { $0.appearance == .dark })
    }

    @Test func fallsBackToTheSystemAppearanceWhenTheFrontendDoesNotSay() throws {
        let message = try #require(makeMessage(
            body: ["variables": [["name": "--primary-color", "value": "rgb(0, 0, 0)"]]],
            fallbackAppearance: .dark
        ))

        #expect(message.appearance == .dark)
    }

    @Test func themeNameIsOptional() throws {
        let message = try #require(makeMessage(
            body: ["variables": [["name": "--primary-color", "value": "rgb(0, 0, 0)"]]]
        ))

        #expect(message.variables.first?.themeName == nil)
    }

    /// Dropping an unusable payload is what keeps a good theme from being replaced by an empty one.
    @Test func rejectsPayloadsWithNothingWorthStoring() {
        #expect(makeMessage(body: [:]) == nil)
        #expect(makeMessage(body: ["variables": "not an array"]) == nil)
        #expect(makeMessage(body: ["variables": []]) == nil)
        // Entries missing a name or a value are individually skipped, and a payload of only those is
        // indistinguishable from an empty one.
        #expect(makeMessage(body: ["variables": [["value": "rgb(0, 0, 0)"], ["name": "--x"]]]) == nil)
    }

    @Test func skipsMalformedEntriesButKeepsTheRest() throws {
        let message = try #require(makeMessage(body: ["variables": [
            ["name": "--primary-color", "value": "rgb(0, 0, 0)"],
            ["name": 42, "value": "rgb(1, 1, 1)"],
            ["name": "--missing-value"],
        ]]))

        #expect(message.variables.map(\.name) == ["--primary-color"])
    }

    private func makeMessage(
        body: [String: Any],
        fallbackAppearance: FrontendThemeAppearance = .light
    ) -> FrontendThemeCaptureMessage? {
        FrontendThemeCaptureMessage(
            messageBody: body,
            serverId: "server-1",
            fallbackAppearance: fallbackAppearance,
            capturedAt: capturedAt
        )
    }
}
