#if os(macOS)
import SwiftUI

private struct IsPresentedInMacSheetKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether the view is the content of a sheet on a Mac window, put there in place of what iOS shows
    /// full screen. A screen that draws its own dimming and card for iOS reads this to draw the card alone:
    /// the sheet already is the panel, and already dims the window behind it.
    var isPresentedInMacSheet: Bool {
        get { self[IsPresentedInMacSheetKey.self] }
        set { self[IsPresentedInMacSheetKey.self] = newValue }
    }
}
#endif
