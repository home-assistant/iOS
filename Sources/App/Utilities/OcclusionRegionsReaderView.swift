#if os(iOS)
import SwiftUI

/// Reads the system's reserved occlusion regions and reports the horizontal insets that keep content clear of them.
final class OcclusionRegionsReaderView: UIView {
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

    static func horizontalInsets(
        avoiding regions: [CGRect],
        in bounds: CGRect,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) -> EdgeInsets {
        var left: CGFloat = 0
        var right: CGFloat = 0
        for region in regions where region.intersects(bounds) {
            if region.midX > bounds.midX {
                right = max(right, bounds.maxX - region.minX)
            } else {
                left = max(left, region.maxX - bounds.minX)
            }
        }
        return layoutDirection == .rightToLeft
            ? EdgeInsets(top: 0, leading: right, bottom: 0, trailing: left)
            : EdgeInsets(top: 0, leading: left, bottom: 0, trailing: right)
    }

    static func frames(ofActiveRegions regions: [NSObject]) -> [CGRect] {
        regions.compactMap { region in
            guard describesRegion(region), region.value(forKey: "active") as? Bool == true else { return nil }
            return (region.value(forKey: "frame") as? NSValue)?.cgRectValue
        }
    }

    private static func describesRegion(_ object: NSObject) -> Bool {
        ["isActive", "frame"].allSatisfy { object.responds(to: NSSelectorFromString($0)) }
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
        let value = Self.horizontalInsets(
            avoiding: Self.frames(ofActiveRegions: reservedOcclusionRegions()),
            in: bounds,
            layoutDirection: effectiveUserInterfaceLayoutDirection
        )
        guard value != lastReported else { return }
        lastReported = value
        onChange?(value)
    }

    private func reservedOcclusionRegions() -> [NSObject] {
        guard #available(iOS 27.1, macOS 27.1, *),
              let kindClass = NSClassFromString(Self.kindClassName) as? NSObject.Type,
              kindClass.responds(to: NSSelectorFromString(Self.occlusionKindSelector)),
              responds(to: NSSelectorFromString(Self.regionsSelector)),
              let kind = kindClass.perform(NSSelectorFromString(Self.occlusionKindSelector))?.takeUnretainedValue(),
              let regions = perform(NSSelectorFromString(Self.regionsSelector), with: kind)?
              .takeUnretainedValue() as? [NSObject] else {
            return []
        }
        return regions
    }
}
#endif
