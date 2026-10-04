@testable import HomeAssistant
@testable import Shared
import Testing

/// The live template preview short-circuits everything that needs no server: an empty template, and
/// plain text without Jinja markers, render immediately; only a real template waits for the debounce.
@MainActor
struct TemplateRendererTests {
    @Test func startsIdleAndIgnoresAnUnchangedEmptyTemplate() {
        let renderer = TemplateRenderer(server: Server.fake(), debounceInterval: 600)
        #expect(renderer.output == .idle)

        renderer.updateTemplate("")
        #expect(renderer.output == .idle)

        renderer.refreshNow()
        #expect(renderer.output == .success(""))
    }

    @Test func plainTextRendersAsItself() {
        let renderer = TemplateRenderer(server: Server.fake(), debounceInterval: 600)
        renderer.updateTemplate("Hello world")
        #expect(renderer.output == .success("Hello world"))

        // Plain text skips the display validation, which only applies to rendered results.
        let strict = TemplateRenderer(
            server: Server.fake(),
            debounceInterval: 600,
            displayResult: { try ComplicationEditViewModel.validatePercentile($0) }
        )
        strict.updateTemplate("not a fraction")
        #expect(strict.output == .success("not a fraction"))
    }

    @Test func clearingTheTemplateRendersEmpty() {
        let renderer = TemplateRenderer(server: Server.fake(), debounceInterval: 600)
        renderer.updateTemplate("Text")
        renderer.updateTemplate("")
        #expect(renderer.output == .success(""))
    }

    @Test func aJinjaTemplateWaitsForTheDebounce() {
        // A long debounce so the subscription never starts during the test; deinit cancels the timer.
        let renderer = TemplateRenderer(server: Server.fake(), debounceInterval: 600)
        renderer.updateTemplate("{{ states('sensor.x') }}")
        #expect(renderer.output == .loading)
    }

    @Test func switchingServerRerendersImmediately() {
        let renderer = TemplateRenderer(server: Server.fake(), debounceInterval: 600)
        renderer.updateTemplate("Plain")
        renderer.updateServer(Server.fake())
        #expect(renderer.output == .success("Plain"))
    }

    @Test func outputEqualityComparesCaseAndPayload() {
        #expect(TemplateRenderer.Output.idle == .idle)
        #expect(TemplateRenderer.Output.loading == .loading)
        #expect(TemplateRenderer.Output.success("a") == .success("a"))
        #expect(TemplateRenderer.Output.success("a") != .success("b"))
        #expect(TemplateRenderer.Output.failure("a") == .failure("a"))
        #expect(TemplateRenderer.Output.failure("a") != .failure("b"))
        #expect(TemplateRenderer.Output.success("a") != .failure("a"))
        #expect(TemplateRenderer.Output.idle != .loading)
    }
}
