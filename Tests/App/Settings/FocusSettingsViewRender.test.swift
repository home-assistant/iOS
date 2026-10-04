import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Lays the Focus settings screens out so SwiftUI evaluates their bodies, with and without names,
/// against an in-memory database.
@MainActor
final class FocusSettingsViewRenderTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousFocusFilter: FocusFilterWrapper!

    override func setUp() async throws {
        let database = try DatabaseQueue()
        try FocusNameTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { database }
        previousFocusFilter = Current.focusFilter
        Current.focusFilter = FocusFilterWrapper()
    }

    override func tearDown() async throws {
        Current.database = previousDatabase
        Current.focusFilter = previousFocusFilter
    }

    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1600))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        // The names are loaded in `onAppear`, which lands after the first pass.
        try? await Task.sleep(nanoseconds: 50_000_000)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)

        window.isHidden = true
        window.rootViewController = nil
    }

    func testRendersWithoutNames() async {
        XCTAssertTrue(FocusName.all().isEmpty)
        await render(NavigationView { FocusSettingsView() })
    }

    func testRendersWithNames() async {
        FocusName(name: "Work").save()
        FocusName(name: "Sleep").save()
        XCTAssertEqual(FocusName.all().count, 2)

        await render(NavigationView { FocusSettingsView() })
    }

    func testRendersHowItWorks() async {
        await render(NavigationView { FocusHowItWorksView() })
    }

    func testSearchEntriesCoverTheNamesSection() {
        let titles = FocusSettingsView.settingsSearchEntries.map(\.title)

        XCTAssertEqual(titles, [L10n.Focus.Names.header, L10n.Focus.Names.add, L10n.Focus.HowItWorks.title])
    }
}
