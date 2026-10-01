#if !os(watchOS)
import HAIconic
import SwiftUI

/// The cog that opens the app's own settings.
///
/// Frontend counterpart: none. The web frontend reaches settings through its sidebar, not through
/// a button; this belongs to the companion app's chrome.
public struct SettingsButton: View {
    private let action: () -> Void
    private let tint: Color

    public init(tint: Color = Color.gray, action: @escaping (() -> Void)) {
        self.action = action
        self.tint = tint
    }

    public var body: some View {
        Button(action: {
            action()
        }, label: {
            Image(
                uiImage: MaterialDesignIcons.cogIcon.image(
                    ofSize: .init(width: 25, height: 25), color: UIColor(tint)
                )
            )
            #if os(macOS)
            // As a sheet's primary action AppKit draws the button filled with the accent colour, which is
            // the tint the icon is drawn in; a template takes the button's own label colour instead.
            .renderingMode(.template)
            #endif
        })
    }
}

#Preview {
    VStack {
        SettingsButton {}
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding()
        Spacer()
    }
}
#endif
