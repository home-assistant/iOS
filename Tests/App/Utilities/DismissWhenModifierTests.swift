import Combine
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

private final class SheetState: ObservableObject {
    @Published var isShown = true
    @Published var isDismissRequested = false
}

private struct DismissingSheet: View {
    @ObservedObject var state: SheetState

    var body: some View {
        Text(verbatim: "Presented")
            .dismiss(when: state.isDismissRequested)
    }
}

private struct SheetHost: View {
    @ObservedObject var state: SheetState

    var body: some View {
        Color.clear
            .sheet(isPresented: $state.isShown) {
                DismissingSheet(state: state)
            }
    }
}

@MainActor
struct DismissWhenModifierTests {
    @Test func dismissesThePresentationOnceTheTriggerTurnsTrue() {
        let state = SheetState()
        let root = UIHostingController(rootView: SheetHost(state: state))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = root
        // Presentation and dismissal only run in a key window, so this one takes it for the test's duration.
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        settle(until: { root.presentedViewController != nil })
        #expect(root.presentedViewController != nil)

        state.isDismissRequested = true

        settle(until: { !state.isShown })
        #expect(state.isShown == false)
    }

    /// Runs the main loop until `condition` holds or a few seconds pass.
    private func settle(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(3)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }
}
