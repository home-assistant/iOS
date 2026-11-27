import SwiftUI

/// How far content laid out inside the safe area must shift to sit at the centre of the whole screen.
enum SafeAreaCenteringOffset {
    static func horizontal(safeAreaInsets: EdgeInsets) -> CGFloat {
        (safeAreaInsets.trailing - safeAreaInsets.leading) / 2
    }

    static func vertical(safeAreaInsets: EdgeInsets) -> CGFloat {
        (safeAreaInsets.bottom - safeAreaInsets.top) / 2
    }
}
