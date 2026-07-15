#if !os(watchOS)
import SwiftUI

/// A picture-in-picture style panel that floats over its container: the user can drag it anywhere
/// and it snaps to the nearest corner on release, and can shrink it (pinch, or tap to toggle
/// between small and full size) to keep it out of the way.
///
/// Place it in an `.overlay` covering the area the panel may float over — it fills that space and
/// anchors the panel within it.
public struct FloatingPanel<Content: View>: View {
    public enum Corner: CaseIterable {
        case topLeading
        case topTrailing
        case bottomLeading
        case bottomTrailing
    }

    /// The corner the panel is currently anchored to.
    @State private var corner: Corner
    /// Live drag translation; reset to zero when the drag ends and the panel snaps to a corner.
    @State private var dragTranslation: CGSize = .zero
    /// Persisted zoom, kept in `minScale...1`.
    @State private var scale: CGFloat
    /// Transient pinch factor, applied on top of `scale` while the gesture is active.
    @GestureState private var pinchScale: CGFloat = 1
    /// The content's natural (unscaled) size, measured to compute the corner anchor positions.
    @State private var contentSize: CGSize = .zero

    private let minScale: CGFloat
    private let cornerRadius: CGFloat
    private let content: () -> Content

    public init(
        initialCorner: Corner = .topTrailing,
        initialScale: CGFloat = 1,
        minScale: CGFloat = 0.5,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.four,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _corner = State(initialValue: initialCorner)
        _scale = State(initialValue: min(max(initialScale, minScale), 1))
        self.minScale = minScale
        self.cornerRadius = cornerRadius
        self.content = content
    }

    public var body: some View {
        GeometryReader { geometry in
            let effectiveScale = min(max(scale * pinchScale, minScale), 1)
            let panelSize = CGSize(
                width: contentSize.width * effectiveScale,
                height: contentSize.height * effectiveScale
            )
            content()
                .padding(DesignSystem.Spaces.one)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                )
                // Lay the content out at its ideal size: the sizing frame below proposes the scaled
                // (initially zero) size, which would otherwise squash flexible content like text.
                .fixedSize()
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear
                            .onAppear { contentSize = contentGeometry.size }
                            .onChange(of: contentGeometry.size) { newSize in contentSize = newSize }
                    }
                )
                .scaleEffect(effectiveScale)
                // scaleEffect doesn't change the layout footprint, so shrink the frame to the scaled
                // size ourselves — otherwise the panel would anchor as if it were still full size.
                .frame(width: max(panelSize.width, 1), height: max(panelSize.height, 1))
                .position(anchoredPosition(panelSize: panelSize, container: geometry.size))
                // Hidden until the first layout pass has measured the content, so the panel doesn't
                // flash at a wrong position.
                .opacity(contentSize == .zero ? 0 : 1)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        scale = scale > (minScale + 1) / 2 ? minScale : 1
                    }
                }
                // Simultaneous, so the drag doesn't wait for the tap recognizer to fail — otherwise
                // the panel wouldn't follow the finger and would only jump at the end of the drag.
                .simultaneousGesture(
                    SimultaneousGesture(
                        DragGesture()
                            .onChanged { value in dragTranslation = value.translation }
                            .onEnded { value in
                                let anchor = center(of: corner, panelSize: panelSize, container: geometry.size)
                                // Use the predicted end so a flick sends the panel to the corner the
                                // user threw it toward, not just where the finger lifted.
                                let settled = CGPoint(
                                    x: anchor.x + value.predictedEndTranslation.width,
                                    y: anchor.y + value.predictedEndTranslation.height
                                )
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    corner = nearestCorner(to: settled, container: geometry.size)
                                    dragTranslation = .zero
                                }
                            },
                        MagnificationGesture()
                            .updating($pinchScale) { value, state, _ in state = value }
                            .onEnded { value in scale = min(max(scale * value, minScale), 1) }
                    )
                )
        }
    }

    private func anchoredPosition(panelSize: CGSize, container: CGSize) -> CGPoint {
        let anchor = center(of: corner, panelSize: panelSize, container: container)
        return CGPoint(x: anchor.x + dragTranslation.width, y: anchor.y + dragTranslation.height)
    }

    /// The panel's center point when anchored to `corner`, inset from the container edges.
    private func center(of corner: Corner, panelSize: CGSize, container: CGSize) -> CGPoint {
        let inset = DesignSystem.Spaces.two
        let x: CGFloat = switch corner {
        case .topLeading, .bottomLeading: inset + panelSize.width / 2
        case .topTrailing, .bottomTrailing: container.width - inset - panelSize.width / 2
        }
        let y: CGFloat = switch corner {
        case .topLeading, .topTrailing: inset + panelSize.height / 2
        case .bottomLeading, .bottomTrailing: container.height - inset - panelSize.height / 2
        }
        return CGPoint(x: x, y: y)
    }

    private func nearestCorner(to point: CGPoint, container: CGSize) -> Corner {
        switch (point.x < container.width / 2, point.y < container.height / 2) {
        case (true, true): .topLeading
        case (false, true): .topTrailing
        case (true, false): .bottomLeading
        case (false, false): .bottomTrailing
        }
    }
}

#Preview {
    Color(white: 0.9)
        .ignoresSafeArea()
        .overlay {
            FloatingPanel(initialCorner: .topTrailing) {
                Text(verbatim: "Drag me")
                    .padding()
            }
        }
}
#endif
