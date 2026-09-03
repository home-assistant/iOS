import SFSafeSymbols
import Shared
import SwiftUI
import UIKit

/// Renders a What's New icon, whether it is an SF Symbol or a Material Design glyph, in one colour.
struct WhatsNewIconView: View {
    let icon: WhatsNewIcon
    let color: UIColor

    var body: some View {
        switch icon {
        case let .sfSymbol(symbol):
            Image(systemSymbol: symbol)
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(Color(uiColor: color))
        case let .materialDesign(icon):
            Image(uiImage: icon.image(ofSize: CGSize(width: 38, height: 38), color: color))
                .renderingMode(.template)
                .foregroundStyle(Color(uiColor: color))
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        WhatsNewIconView(icon: .sfSymbol(.boltFill), color: .haPrimary)
        WhatsNewIconView(icon: .materialDesign(.microphoneIcon), color: .haPrimary)
    }
    .padding()
}
