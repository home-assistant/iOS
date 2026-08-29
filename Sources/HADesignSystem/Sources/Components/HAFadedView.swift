#if !os(watchOS)
import SwiftUI

/// Clips tall content to a fixed height and fades its bottom edge away, expanding to the full height
/// when tapped. The SwiftUI counterpart of the frontend's `ha-faded`.
///
/// Content only a little taller than the limit is shown in full instead: cutting off two lines to
/// save fifty points is more annoying than the scroll it avoids. The frontend uses the same 50px
/// grace.
public struct HAFadedView<Content: View>: View {
    private let fadedHeight: CGFloat
    private let content: Content

    @State private var contentHeight: CGFloat = 0
    @State private var isExpanded = false

    public init(fadedHeight: CGFloat = 102, @ViewBuilder content: () -> Content) {
        self.fadedHeight = fadedHeight
        self.content = content()
    }

    /// Fading is pointless — and the tap target misleading — unless the content is meaningfully
    /// taller than the limit.
    private var shouldFade: Bool {
        !isExpanded && contentHeight > fadedHeight + 50
    }

    public var body: some View {
        content
            // Take the height the content wants at the offered width, rather than letting the
            // height limit below propose a shorter box — text answers that by truncating to a
            // single line instead of wrapping, which is the opposite of what fading is for.
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear { contentHeight = proxy.size.height }
                }
            )
            .frame(maxHeight: shouldFade ? fadedHeight : nil, alignment: .top)
            .clipped()
            .mask(
                LinearGradient(
                    stops: shouldFade
                        // Opaque for the first quarter, then falling away to nothing, as the
                        // frontend's `mask-image` does.
                        ? [.init(color: .black, location: 0.25), .init(color: .clear, location: 1)]
                        : [.init(color: .black, location: 0), .init(color: .black, location: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard shouldFade else { return }
                isExpanded = true
            }
    }
}

#Preview("Faded") {
    HAFadedView {
        Text(String(repeating: "This paragraph is long enough to be cut off and faded. ", count: 8))
    }
    .padding()
}

#Preview("Short enough to show in full") {
    HAFadedView {
        Text("A single short line.")
    }
    .padding()
}

extension HAFadedView: FrontendComponent {
    public static var frontendComponentName: String { "ha-faded" }
}

#endif
