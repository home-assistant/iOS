#if os(macOS)
import SwiftUI

/// What `MacSwiftUISheetHostView` shows, and the switch that closes it from AppKit code.
final class MacSwiftUISheetModel: ObservableObject {
    @Published var isPresented = true

    let screen: AnyView
    /// The size the sheet takes. `nil` leaves the sheet to size itself to the screen, which suits a screen
    /// that knows how big it is, such as a bottom sheet.
    let size: CGSize?
    /// Called once the sheet is gone, whether the screen dismissed itself or AppKit code closed it.
    var onDismiss: (() -> Void)?

    init(screen: AnyView, size: CGSize?) {
        self.screen = screen
        self.size = size
    }
}
#endif
