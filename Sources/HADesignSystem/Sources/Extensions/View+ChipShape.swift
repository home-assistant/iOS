#if !os(watchOS)
import SwiftUI

extension View {
    /// The Material 3 chip box the frontend's three chip elements share — `ha-assist-chip`,
    /// `ha-filter-chip` and `ha-input-chip`: 32pt tall, a 1pt outline in the divider colour, and a
    /// 14pt label.
    ///
    /// Shared so `HAAssistChip`, `HAFilterChip` and `HAInputChip` cannot drift apart in the metrics
    /// they are supposed to have in common — they differ only in corner radius and fill.
    func haChipShape(cornerRadius: CGFloat, background: Color, showsOutline: Bool) -> some View {
        font(.system(size: 14))
            .foregroundStyle(Color(uiColor: .label))
            .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
            .frame(height: 32)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        showsOutline ? Color.haDivider : .clear,
                        lineWidth: DesignSystem.Border.Width.default
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
#endif
