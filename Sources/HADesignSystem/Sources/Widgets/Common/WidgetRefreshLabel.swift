#if !os(watchOS)
import Foundation
import SFSafeSymbols
import SwiftUI

/// The time an entry was last refreshed, preceded by a small reload glyph.
///
/// Every widget that can be reloaded shows this pair, and the pair is one control — the widget wraps
/// it in whatever performs the reload, which is why the button itself isn't here.
public struct WidgetRefreshLabel: View {
    private let date: Date
    private let font: Font
    /// `nil` uses the secondary content style, which is what most widgets want.
    private let color: Color?

    public init(date: Date, font: Font = .system(size: 11), color: Color? = nil) {
        self.date = date
        self.font = font
        self.color = color
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spaces.micro) {
            Image(systemSymbol: .arrowClockwise)
                .font(.system(size: 9, weight: .semibold))
            Text(date, style: .time)
                .font(font)
        }
        .foregroundStyle(color ?? Color.secondary)
        .lineLimit(1)
    }
}

#Preview {
    WidgetRefreshLabel(date: Date(timeIntervalSince1970: 1_700_000_000))
        .padding()
}
#endif
