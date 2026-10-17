import SwiftUI

/// How far content laid out inside the safe area must shift to sit at the centre of the whole screen.
enum SafeAreaCenteringOffset {
    static func horizontal(safeAreaInsets: EdgeInsets, layoutDirection: LayoutDirection) -> CGFloat {
        let (left, right) = layoutDirection == .rightToLeft
            ? (safeAreaInsets.trailing, safeAreaInsets.leading)
            : (safeAreaInsets.leading, safeAreaInsets.trailing)
        return (right - left) / 2
    }

    static func vertical(safeAreaInsets: EdgeInsets) -> CGFloat {
        (safeAreaInsets.bottom - safeAreaInsets.top) / 2
    }
}
