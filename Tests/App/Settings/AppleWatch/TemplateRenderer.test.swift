import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: the renderer looks its API up through `Current.api(for:)` from a timer on the main
/// run loop, outside the test's task, so the API cache is swapped globally.
@Suite(.sharedState)
@MainActor
struct TemplateRendererTests {
    @Test func emptyAndPlainTemplatesRenderWithoutTheServer() async {
        let renderer = TemplateRenderer(server: .fake())
        #expect(renderer.output == .idle)

        renderer.refreshNow()
        #expect(renderer.output == .success(""))

        renderer.updateTemplate("Just text")
        #expect(renderer.output == .success("Just text"))
        // Setting the same template again does nothing.
        renderer.updateTemplate("Just text")
        #expect(renderer.output == .success("Just text"))
    }

    @Test func templateFailsWithoutAnAPI() async {
        let offline = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let renderer = TemplateRenderer(server: offline)
        renderer.updateTemplate("{{ states('sun.sun') }}", skipDelay: true)
        #expect(renderer.output == .loading)
        await #expect(waitUntil { if case .failure = renderer.output { true } else { false } })
    }

    @Test func rendersResultsAndErrorsFromTheSubscription() async throws {
        try await withConnection { server, connection in
            let renderer = TemplateRenderer(server: server)
            renderer.updateTemplate("{{ 1 + 1 }}", skipDelay: true)
            #expect(renderer.output == .loading)
            try await #require(waitUntil { connection.pendingSubscriptions.count == 1 })
            let subscription = try #require(connection.pendingSubscriptions.last)
            #expect(subscription.request.data["template"] as? String == "{{ 1 + 1 }}")

            subscription.handler(subscription.cancellable, HAData(value: ["result": 2]))
            await #expect(waitUntil { renderer.output == .success("2") })

            subscription.handler(subscription.cancellable, HAData(value: ["error": "Bad template"]))
            await #expect(waitUntil { renderer.output == .failure("Bad template") })

            // An event with neither a result nor an error fails with the decoding error, which
            // replaces the previous failure once the main queue delivers it.
            subscription.handler(subscription.cancellable, HAData(value: ["unexpected": true]))
            await #expect(waitUntil {
                if case let .failure(message) = renderer.output { message != "Bad template" } else { false }
            })

            subscription.initiated(.failure(.internal(debugDescription: "connection lost")))
            await #expect(waitUntil { if case .failure = renderer.output { true } else { false } })
        }
    }

    @Test func displayResultErrorsBecomeFailures() async throws {
        try await withConnection { server, connection in
            let renderer = TemplateRenderer(server: server) {
                try ComplicationEditViewModel.validatePercentile($0)
            }
            renderer.updateTemplate("{{ 5 }}", skipDelay: true)
            try await #require(waitUntil { connection.pendingSubscriptions.count == 1 })
            let subscription = try #require(connection.pendingSubscriptions.last)
            subscription.handler(subscription.cancellable, HAData(value: ["result": 5]))
            await #expect(waitUntil { if case .failure = renderer.output { true } else { false } })

            subscription.handler(subscription.cancellable, HAData(value: ["result": 0.5]))
            await #expect(waitUntil { renderer.output == .success("0.5") })
        }
    }

    @Test func typingIsDebouncedAndServerChangesResubscribe() async throws {
        try await withConnection { server, connection in
            let renderer = TemplateRenderer(server: server, debounceInterval: 0.01)
            renderer.updateTemplate("{{ 1 }}")
            renderer.updateTemplate("{{ 2 }}")
            try await #require(waitUntil { connection.pendingSubscriptions.count == 1 })
            #expect(connection.pendingSubscriptions[0].request.data["template"] as? String == "{{ 2 }}")

            renderer.updateServer(server)
            await #expect(waitUntil { connection.pendingSubscriptions.count == 2 })
            #expect(connection.pendingSubscriptions[0].cancellable.wasCancelled)
        }
    }

    @Test func newerServersAskForErrorReports() async throws {
        try await withConnection(version: .init(major: 2024, minor: 1)) { server, connection in
            let renderer = TemplateRenderer(server: server)
            renderer.updateTemplate("{{ 3 }}", skipDelay: true)
            try await #require(waitUntil { connection.pendingSubscriptions.count == 1 })
            #expect(connection.pendingSubscriptions[0].request.data["report_errors"] as? Bool == true)
        }
    }

    @Test func outputsCompareByCaseAndValue() async {
        typealias Output = TemplateRenderer.Output
        #expect(Output.idle == .idle)
        #expect(Output.loading == .loading)
        #expect(Output.success("a") == .success("a"))
        #expect(Output.success("a") != .success("b"))
        #expect(Output.failure("a") == .failure("a"))
        #expect(Output.failure("a") != .success("a"))
        #expect(Output.idle != .loading)
    }

    /// The editor section shows a failed render in red, and hands every edit to its renderer.
    @Test func previewSectionShowsFailuresAndRendersEdits() async throws {
        let offline = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        let renderer = TemplateRenderer(server: offline)
        let box = TemplateBox(template: "{{ states('sun.sun') }}")
        let driver = await SwiftUIScreenDriver.show(TemplateSectionHost(box: box, renderer: renderer))
        defer { driver.close() }
        await #expect(waitUntil { if case .failure = renderer.output { true } else { false } })
        await driver.settle()

        box.template = "{{ 1 }}"
        await driver.settle()
        #expect(renderer.output != .idle)
    }

    private func withConnection(
        version: Version? = nil,
        _ body: (Server, HAMockConnection) async throws -> Void
    ) async throws {
        let previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        var info = ServerInfo.fake()
        if let version {
            info.version = version
        }
        let server = servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: info)
        let api = HomeAssistantAPI(server: server)
        let connection = HAMockConnection()
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        defer {
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
        }
        try await body(server, connection)
    }

    /// Polls `condition`, handing the main thread back to its run loop between checks so the
    /// renderer's timers and main-queue callbacks run.
    private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }
}

@MainActor
private final class TemplateBox: ObservableObject {
    @Published var template: String

    init(template: String) {
        self.template = template
    }
}

private struct TemplateSectionHost: View {
    @ObservedObject var box: TemplateBox
    let renderer: TemplateRenderer

    var body: some View {
        List {
            TemplatePreviewSection(
                header: "Header",
                footer: "Footer",
                title: "Template",
                placeholder: "{{ }}",
                template: $box.template,
                renderer: renderer
            )
        }
    }
}
