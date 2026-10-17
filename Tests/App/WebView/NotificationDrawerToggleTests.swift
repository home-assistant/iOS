import Foundation
@testable import HomeAssistant
import Testing

struct NotificationDrawerToggleTests {
    private struct ProbeError: Error {}

    private func toggle(
        probeResult: Any?,
        error: (any Error)? = nil,
        onShow: @escaping () -> Void
    ) -> (script: String?, toggle: NotificationDrawerToggle) {
        var script: String?
        let toggle = NotificationDrawerToggle(
            evaluateJavaScript: { evaluated, completion in
                script = evaluated
                completion(probeResult, error)
            },
            showDrawer: onShow
        )
        toggle.toggle()
        return (script, toggle)
    }

    @Test("A closed drawer is opened through the frontend after the probe finds nothing to close")
    func opensAClosedDrawer() {
        var shown = 0
        let (script, _) = toggle(probeResult: false) { shown += 1 }
        #expect(script == WebViewJavascriptCommands.closeNotificationDrawerIfOpen)
        #expect(shown == 1)
    }

    @Test("An open drawer is closed by the probe and not reopened")
    func closesAnOpenDrawer() {
        var shown = 0
        _ = toggle(probeResult: true) { shown += 1 }
        #expect(shown == 0)
    }

    @Test("A probe that fails or answers nothing falls back to opening the drawer")
    func fallsBackToOpening() {
        var shown = 0
        _ = toggle(probeResult: nil, error: ProbeError()) { shown += 1 }
        _ = toggle(probeResult: "yes") { shown += 1 }
        #expect(shown == 2)
    }

    @Test("The probe looks for the frontend's drawer and its public close hook")
    func probeTargetsTheDrawer() {
        let script = WebViewJavascriptCommands.closeNotificationDrawerIfOpen
        #expect(script.contains("querySelector('notification-drawer')"))
        #expect(script.contains("ha-drawer[open]"))
        #expect(script.contains("drawer.closeDialog()"))
    }
}
