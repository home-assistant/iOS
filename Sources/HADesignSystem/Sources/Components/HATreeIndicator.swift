#if !os(watchOS)
import SwiftUI

/// The dashed elbow drawn beside a nested row to show it belongs to the row above. The SwiftUI
/// counterpart of the frontend's `ha-tree-indicator`.
///
/// The vertical line spans the whole height so consecutive children join into one trunk; the last
/// child stops it halfway, which is what `end` selects.
public struct HATreeIndicator: View {
    private let isEnd: Bool
    private let height: CGFloat

    /// - Parameters:
    ///   - isEnd: `true` for the last child, which stops the trunk at the elbow instead of carrying
    ///     it down to the next row.
    ///   - height: Match the row this sits beside, so consecutive indicators join without a gap.
    ///     The frontend's default box is 48×48.
    public init(isEnd: Bool = false, height: CGFloat = 48) {
        self.isEnd = isEnd
        self.height = height
    }

    public var body: some View {
        // The frontend stretches a 48×48 viewBox with `preserveAspectRatio="none"`, so the elbow
        // always sits at half the height whatever the row is worth.
        GeometryReader { proxy in
            Path { path in
                let midX = proxy.size.width / 2
                let midY = proxy.size.height / 2
                path.move(to: CGPoint(x: midX, y: 0))
                path.addLine(to: CGPoint(x: midX, y: isEnd ? midY : proxy.size.height))
                path.move(to: CGPoint(x: midX, y: midY))
                path.addLine(to: CGPoint(x: midX + proxy.size.width / 4, y: midY))
            }
            .stroke(
                Color.haDivider,
                style: StrokeStyle(lineWidth: 2, dash: [2, 2])
            )
        }
        .frame(width: 48, height: height)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: .zero) {
        VStack(spacing: .zero) {
            HATreeIndicator()
            HATreeIndicator()
            HATreeIndicator(isEnd: true)
        }
        VStack(alignment: .leading, spacing: .zero) {
            Text("Ceiling light").frame(height: 48)
            Text("Desk lamp").frame(height: 48)
            Text("Floor lamp").frame(height: 48)
        }
    }
    .padding()
}

#Preview("Taller rows") {
    HStack(spacing: .zero) {
        VStack(spacing: .zero) {
            HATreeIndicator(height: 72)
            HATreeIndicator(isEnd: true, height: 72)
        }
        VStack(alignment: .leading, spacing: .zero) {
            Text("Ceiling light").frame(height: 72)
            Text("Desk lamp").frame(height: 72)
        }
    }
    .padding()
}

extension HATreeIndicator: FrontendComponent {
    public static var frontendComponentName: String { "ha-tree-indicator" }
}

#endif
