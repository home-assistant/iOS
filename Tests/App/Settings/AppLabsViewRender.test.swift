import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the screen out the way Settings does, which is what evaluates the body — the feature
/// toggles and the voice tools server row — rather than only the visibility and search helpers.
@MainActor
@Suite(.serialized)
struct AppLabsViewRenderTests {
    @Test func rendersTheFeaturesAndTheVoiceToolsServerRow() throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousIsTestFlight = Current.isTestFlight
        Current.database = { database }
        Current.isTestFlight = true
        defer {
            Current.database = previousDatabase
            Current.isTestFlight = previousIsTestFlight
        }

        let controller = UIHostingController(rootView: NavigationView { AppLabsView() })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }
}
