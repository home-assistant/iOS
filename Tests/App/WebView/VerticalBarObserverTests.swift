import Foundation
@testable import HomeAssistant
import Testing
import UIKit

@MainActor
struct VerticalBarObserverTests {
    @Test("A trait collection without a vertical bar edge reports no vertical bar")
    func traitsWithoutVerticalBar() {
        #expect(!VerticalBarObserver.ObserverViewController.hasVerticalBar(in: UITraitCollection()))
        #expect(!VerticalBarObserver.ObserverViewController.hasVerticalBar(
            in: UITraitCollection(horizontalSizeClass: .regular)
        ))
    }

    @Test("The observer stays out of the way and reports once per change, on appearance and layout")
    func reportsOnAppearanceAndLayout() {
        let controller = VerticalBarObserver.ObserverViewController()
        var reported: [Bool] = []
        controller.onChange = { reported.append($0) }

        controller.loadViewIfNeeded()
        #expect(!controller.view.isUserInteractionEnabled)
        #expect(controller.view.backgroundColor == .clear)
        controller.viewWillAppear(false)
        #expect(reported == [false])

        controller.viewDidLayoutSubviews()
        #expect(reported == [false])
    }
}
