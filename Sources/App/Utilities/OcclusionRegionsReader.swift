import SwiftUI
import UIKit

/// Reports how far hardware cutouts such as the camera reach into a view from its sides.
struct OcclusionRegionsReader: UIViewRepresentable {
    @Binding var insets: EdgeInsets

    func makeUIView(context: Context) -> ReaderView {
        ReaderView()
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = { value in
            DispatchQueue.main.async {
                insets = value
            }
        }
    }

    final class ReaderView: UIView {
        private static let kindClassName = "UIViewReservedRegionKind"
        private static let occlusionKindSelector = "occlusionRegionKind"
        private static let regionsSelector = "reservedRegionsOfKind:"

        var onChange: ((EdgeInsets) -> Void)?
        private var lastReported: EdgeInsets?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        static func horizontalInsets(avoiding regions: [CGRect], in bounds: CGRect) -> EdgeInsets {
            var insets = EdgeInsets()
            for region in regions where region.intersects(bounds) {
                if region.midX > bounds.midX {
                    insets.trailing = max(insets.trailing, bounds.maxX - region.minX)
                } else {
                    insets.leading = max(insets.leading, region.maxX - bounds.minX)
                }
            }
            return insets
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        private func report() {
            let value = Self.horizontalInsets(avoiding: activeOcclusionRegions(), in: bounds)
            guard value != lastReported else { return }
            lastReported = value
            onChange?(value)
        }

        private func activeOcclusionRegions() -> [CGRect] {
            guard #available(iOS 27.1, *),
                  let kindClass = NSClassFromString(Self.kindClassName) as? NSObject.Type,
                  kindClass.responds(to: NSSelectorFromString(Self.occlusionKindSelector)),
                  responds(to: NSSelectorFromString(Self.regionsSelector)),
                  let kind = kindClass.perform(NSSelectorFromString(Self.occlusionKindSelector))?.takeUnretainedValue(),
                  let regions = perform(NSSelectorFromString(Self.regionsSelector), with: kind)?
                  .takeUnretainedValue() as? [NSObject] else {
                return []
            }
            return regions.compactMap { region in
                guard region.value(forKey: "active") as? Bool == true else { return nil }
                return (region.value(forKey: "frame") as? NSValue)?.cgRectValue
            }
        }
    }
}
