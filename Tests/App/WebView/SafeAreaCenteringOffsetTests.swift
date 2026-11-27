import Foundation
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

struct SafeAreaCenteringOffsetTests {
    private struct Marker: UIViewRepresentable {
        let view: UIView

        func makeUIView(context: Context) -> UIView {
            view
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    @Test("A trailing inset shifts content toward the trailing edge and a leading inset toward the leading edge")
    func horizontal() {
        let trailing = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 84)
        let leading = EdgeInsets(top: 0, leading: 84, bottom: 0, trailing: 0)
        #expect(SafeAreaCenteringOffset.horizontal(safeAreaInsets: trailing) == 42)
        #expect(SafeAreaCenteringOffset.horizontal(safeAreaInsets: leading) == -42)
    }

    @MainActor
    @Test("Offsetting by it centers content on the display in both layout directions", arguments: [false, true])
    func offsetCentersContentOnTheDisplay(isRightToLeft: Bool) throws {
        guard #available(iOS 17.0, *) else { return }

        let leadingMarker = UIView()
        let centeredMarker = UIView()
        let controller = UIHostingController(rootView: GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Marker(view: leadingMarker)
                    .frame(width: 10, height: 10)
                Marker(view: centeredMarker)
                    .frame(width: 10, height: 10)
                    .offset(x: SafeAreaCenteringOffset.horizontal(safeAreaInsets: proxy.safeAreaInsets))
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        })
        controller.traitOverrides.layoutDirection = isRightToLeft ? .rightToLeft : .leftToRight
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        for _ in 0 ..< 3 {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }

        let view = try #require(controller.view)
        try #require(leadingMarker.window != nil && centeredMarker.window != nil)
        let leadingMidX = leadingMarker.convert(leadingMarker.bounds, to: view).midX
        let centeredMidX = centeredMarker.convert(centeredMarker.bounds, to: view).midX
        #expect(view.safeAreaInsets.right > view.safeAreaInsets.left)
        #expect((leadingMidX > centeredMidX) == isRightToLeft)
        #expect(abs(centeredMidX - view.bounds.midX) <= 0.5)
    }

    @Test("A taller top inset shifts content up by half the difference")
    func vertical() {
        let insets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        #expect(SafeAreaCenteringOffset.vertical(safeAreaInsets: insets) == -12.5)
    }
}
