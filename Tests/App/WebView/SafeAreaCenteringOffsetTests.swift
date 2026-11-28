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
        let view = try #require(controller.view)
        func midX(of marker: UIView) -> CGFloat {
            marker.convert(marker.bounds, to: view).midX
        }
        func isCentered() -> Bool {
            centeredMarker.window != nil
                && view.safeAreaInsets.right > view.safeAreaInsets.left
                && abs(midX(of: centeredMarker) - view.bounds.midX) <= 0.5
        }
        let deadline = Date().addingTimeInterval(10)
        repeat {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        } while !isCentered() && Date() < deadline

        #expect((midX(of: leadingMarker) > midX(of: centeredMarker)) == isRightToLeft)
        #expect(isCentered())
    }

    @Test("A taller top inset shifts content up by half the difference")
    func vertical() {
        let insets = EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0)
        #expect(SafeAreaCenteringOffset.vertical(safeAreaInsets: insets) == -12.5)
    }
}
