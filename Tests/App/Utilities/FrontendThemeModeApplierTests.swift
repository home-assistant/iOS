@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct FrontendThemeModeApplierTests {
    @Test func aWindowFollowsTheServerItsSceneIsShowing() throws {
        try withHostScene { scene, applier in
            let shown = Identifier<Server>(rawValue: "shown")
            let elsewhere = Identifier<Server>(rawValue: "elsewhere")
            applier.frontend(for: shown, showingIn: { scene })

            applier.setMode(.dark, for: shown)
            #expect(scene.windows.allSatisfy { $0.overrideUserInterfaceStyle == .dark })

            // Another window switching server must not restyle this one.
            applier.setMode(.light, for: elsewhere)
            #expect(scene.windows.allSatisfy { $0.overrideUserInterfaceStyle == .dark })
        }
    }

    @Test func aWindowWithNoServerOfItsOwnFollowsTheFrontendThatReportedLast() throws {
        try withHostScene { scene, applier in
            applier.setMode(.dark, for: .init(rawValue: "settings-has-no-server"))

            #expect(scene.windows.allSatisfy { $0.overrideUserInterfaceStyle == .dark })
        }
    }

    @Test func aFrontendWithNoWindowYetLeavesEveryWindowOnTheFallback() throws {
        try withHostScene { scene, applier in
            let starting = Identifier<Server>(rawValue: "starting")
            // Handed over before it is in a window, which is when `setFrontend` runs.
            applier.frontend(for: starting, showingIn: { nil })

            applier.setMode(.dark, for: starting)

            #expect(scene.windows.allSatisfy { $0.overrideUserInterfaceStyle == .dark })
        }
    }

    @Test func anUnknownServerHasNoModeOfItsOwn() {
        let applier = FrontendThemeModeApplier(windowScenes: { [] })

        #expect(applier.mode(for: .init(rawValue: "never-seen")) == .automatic)
    }

    @Test func aSceneActivatingCatchesUpWindowsOpenedSinceTheModeWasRead() throws {
        try withHostScene { scene, applier in
            applier.setMode(.dark, for: .init(rawValue: "any"))
            for window in scene.windows {
                window.overrideUserInterfaceStyle = .unspecified
            }

            NotificationCenter.default.post(name: UIScene.didActivateNotification, object: nil)

            #expect(scene.windows.allSatisfy { $0.overrideUserInterfaceStyle == .dark })
        }
    }

    /// Drives the real scene the test host runs in, since a `UIWindowScene` cannot be built by hand.
    private func withHostScene(_ body: (UIWindowScene, FrontendThemeModeApplier) throws -> Void) throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        defer {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
        try body(scene, FrontendThemeModeApplier(windowScenes: { [scene] }))
    }
}
