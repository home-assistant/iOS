import Shared
import SwiftUI

/// A small styled mock of how each WidgetKit accessory family looks, used in the builder rows.
struct ComplicationFamilyPreview: View {
    let family: WatchComplicationConfig.Family

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                switch family {
                case .circular:
                    Circle().stroke(Color.accentColor, lineWidth: side * 0.12)
                    Image(systemSymbol: .houseFill).font(.system(size: side * 0.32))
                case .corner:
                    Circle()
                        .trim(from: 0.5, to: 0.75)
                        .stroke(Color.accentColor, lineWidth: side * 0.12)
                    Image(systemSymbol: .houseFill).font(.system(size: side * 0.22))
                case .rectangular:
                    RoundedRectangle(cornerRadius: side * 0.12)
                        .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    VStack(alignment: .leading, spacing: side * 0.06) {
                        Capsule().fill(Color.accentColor).frame(width: side * 0.7, height: side * 0.12)
                        Capsule().fill(Color.secondary.opacity(0.5)).frame(width: side * 0.5, height: side * 0.1)
                    }
                    .padding(side * 0.12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                case .inline:
                    Capsule().stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                    Capsule().fill(Color.accentColor).frame(width: side * 0.6, height: side * 0.12)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}
