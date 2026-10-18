#if !os(watchOS)
import SwiftUI

/// A rounded, filled container for a block of content.
///
/// Frontend counterpart: none directly — `ha-card` is ``HACard``, which came later and carries the
/// header and the frontend's own metrics. This predates it and is what the app's existing screens
/// use. The two overlap and are a candidate for consolidation.
public struct CardView<Content: View>: View {
    public let content: () -> Content
    public let backgroundColor: Color?

    public init(backgroundColor: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content
    }

    public var body: some View {
        VStack(spacing: .zero) {
            content()
                .padding()
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        /* Corner radius is duplicated to assure even with a background color it will
         keep the corner radius */
        .cornerRadius(HACornerRadius.standard)
        .overlay(
            RoundedRectangle(cornerRadius: HACornerRadius.standard)
                .stroke(
                    Color.onSurface, lineWidth: 1
                )
        )
    }
}

#Preview {
    VStack {
        CardView {
            Text("abc")
        }
        .padding()
    }
    .background(Color.yellow)
}
#endif
