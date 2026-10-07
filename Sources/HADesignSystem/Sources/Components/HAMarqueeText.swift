#if !os(watchOS)
import SwiftUI

/// Text that scrolls itself into view when it is wider than the space it has, then scrolls back. The
/// SwiftUI counterpart of the frontend's `ha-marquee-text`.
///
/// It bounces rather than looping: the frontend walks the text left until its far end is flush,
/// pauses, and walks it back. Text that already fits never moves, so this is safe for a label whose
/// length depends on the data.
///
/// Scrolling stops under Reduce Motion, leaving the text parked at its start — moving text is
/// exactly what that setting exists to suppress.
public struct HAMarqueeText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let text: String
    private let speed: Double
    private let pauseDuration: Double
    private let scrolls: Bool

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    /// - Parameters:
    ///   - speed: Points per second, the frontend's pixels per second.
    ///   - pauseDuration: Seconds to rest at each end. The frontend's `pause-duration` is in
    ///     milliseconds and defaults to 1000.
    ///   - scrolls: Pass `false` to park the text at its start and leave it there — for a label the
    ///     caller knows is off-screen, or to hold it still for a snapshot. Reduce Motion overrides
    ///     this to `false` regardless.
    public init(_ text: String, speed: Double = 15, pauseDuration: Double = 1, scrolls: Bool = true) {
        self.text = text
        self.speed = speed
        self.pauseDuration = pauseDuration
        self.scrolls = scrolls
    }

    public var body: some View {
        // The container's width has to come from a proxy rather than a flexible frame: the width the
        // text must be clipped to is only known once the parent has offered one, and `clipped()`
        // applied to a `maxWidth: .infinity` frame clips to whatever that resolved to, which under
        // an unbounded proposal is the text's full width — no clipping at all.
        GeometryReader { proxy in
            Text(text)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { textProxy in
                        Color.clear.onAppear { textWidth = textProxy.size.width }
                    }
                )
                .offset(x: offset)
                .frame(width: proxy.size.width, alignment: .leading)
                .clipped()
                .onAppear { startScrolling(containerWidth: proxy.size.width) }
                .onChange(of: textWidth) { _ in startScrolling(containerWidth: proxy.size.width) }
        }
        .frame(height: textHeight)
        .accessibilityLabel(Text(text))
    }

    /// The row has to reserve a line's worth of height itself, because a `GeometryReader` reports
    /// the space it was given rather than asking its content what it needs.
    private var textHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight
    }

    private func startScrolling(containerWidth: CGFloat) {
        // How far the text has to travel for its trailing edge to come flush with the container's.
        // Zero when the text already fits, which is what keeps short labels still.
        let maxOffset = max(0, textWidth - containerWidth)
        // `speed` is public input; at zero the duration below is infinite and at a negative
        // value it runs backwards, so neither is a scroll worth starting.
        guard maxOffset > 0, speed > 0, scrolls, !reduceMotion else {
            offset = 0
            return
        }
        // Duration from distance and speed, so a longer label scrolls for longer rather than
        // faster — the frontend advances a fixed number of pixels per frame.
        withAnimation(
            .linear(duration: maxOffset / speed)
                .delay(pauseDuration)
                .repeatForever(autoreverses: true)
        ) {
            offset = -maxOffset
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
        HAMarqueeText("Short enough to fit")
        HAMarqueeText("A media title far too long to fit in the space this label has been given")
            .frame(width: 200)
        HAMarqueeText("Faster, with no pause at the ends", speed: 60, pauseDuration: 0)
            .frame(width: 200)
    }
    .padding()
}

#Preview("Held still") {
    HAMarqueeText(
        "A media title far too long to fit in the space this label has been given",
        scrolls: false
    )
    .frame(width: 200)
    .padding()
}

extension HAMarqueeText: FrontendComponent {
    public static var frontendComponentName: String { "ha-marquee-text" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
