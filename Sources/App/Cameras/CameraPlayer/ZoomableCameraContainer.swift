import SwiftUI

/// A reusable container that adds pinch-to-zoom, double-tap-to-zoom and pan
/// support to any camera player content. The zoom/pan math is shared across all
/// camera player types (WebRTC, HLS, MJPEG) so they behave identically.
///
/// - `onInteraction` is called on any zoom/pan gesture (used, e.g., to keep the
///   player controls visible while the user is interacting).
/// - `onSwipeDown` is called when the user swipes down while not zoomed in
///   (used to dismiss the player).
struct ZoomableCameraContainer<Content: View>: View {
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var previousFrameScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let onInteraction: (() -> Void)?
    private let onSwipeDown: (() -> Void)?
    private let content: Content

    init(
        onInteraction: (() -> Void)? = nil,
        onSwipeDown: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onInteraction = onInteraction
        self.onSwipeDown = onSwipeDown
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                content
                    .scaleEffect(.init(floatLiteral: scale >= 1.0 ? scale : 1.0))
                    .offset(offset)
                CameraZoomGestureOverlay(
                    onPinchBegan: { _ in
                        previousFrameScale = lastScale
                    },
                    onPinchChanged: { factor, midpoint in
                        handlePinchChanged(factor: factor, midpoint: midpoint, in: geometry.size)
                    },
                    onPinchEnded: {
                        handlePinchEnded(in: geometry.size)
                    },
                    onDoubleTap: { location in
                        handleDoubleTap(at: location, in: geometry.size)
                    }
                )
            }
            .simultaneousGesture(dragGesture(geometry: geometry))
        }
    }

    private func handlePinchChanged(factor: CGFloat, midpoint: CGPoint, in containerSize: CGSize) {
        let proposedScale = max(lastScale * factor, 1.0)
        let oldScale = max(previousFrameScale, 1.0)
        let ratio = proposedScale / oldScale

        let pX = midpoint.x - containerSize.width / 2
        let pY = midpoint.y - containerSize.height / 2

        let newOffset = CGSize(
            width: pX * (1 - ratio) + offset.width * ratio,
            height: pY * (1 - ratio) + offset.height * ratio
        )

        scale = proposedScale
        offset = clampedOffset(for: newOffset, in: containerSize)
        previousFrameScale = proposedScale
        onInteraction?()
    }

    private func handlePinchEnded(in containerSize: CGSize) {
        lastScale = scale
        previousFrameScale = scale
        onInteraction?()
        if scale <= 1.0 {
            withAnimation {
                offset = .zero
                lastOffset = .zero
            }
        } else {
            withAnimation {
                offset = clampedOffset(for: offset, in: containerSize)
                lastOffset = offset
            }
        }
    }

    private func handleDoubleTap(at location: CGPoint, in containerSize: CGSize) {
        withAnimation(.spring()) {
            if scale > 1.0 {
                scale = 1.0
                lastScale = 1.0
                previousFrameScale = 1.0
                offset = .zero
                lastOffset = .zero
            } else {
                let target: CGFloat = 2.0
                let pX = location.x - containerSize.width / 2
                let pY = location.y - containerSize.height / 2
                let newOffset = CGSize(width: pX * (1 - target), height: pY * (1 - target))
                scale = target
                lastScale = target
                previousFrameScale = target
                offset = clampedOffset(for: newOffset, in: containerSize)
                lastOffset = offset
            }
            onInteraction?()
        }
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(for: newOffset, in: geometry.size)
                onInteraction?()
            }
            .onEnded { value in
                // If user is not zoomed in, allow dismissing the view with a swipe down
                guard scale > 1.0 else {
                    if value.translation.height > 100 {
                        onSwipeDown?()
                    }
                    return
                }
                withAnimation(.spring()) {
                    offset = clampedOffset(for: offset, in: geometry.size)
                    lastOffset = offset
                }
                onInteraction?()
            }
    }

    /// Clamps the dragging offset to prevent the zoomed content from being moved
    /// beyond the visible area. This ensures that when the user pans a zoomed-in view,
    /// it stays within the bounds of the container and avoids showing any empty space
    /// around the edges.
    ///
    /// - Parameters:
    ///   - offset: The proposed offset resulting from the user's drag gesture.
    ///   - containerSize: The size of the visible container (i.e., screen or view bounds).
    /// - Returns: A `CGSize` representing the adjusted offset that keeps the content
    ///            within valid boundaries.
    private func clampedOffset(for offset: CGSize, in containerSize: CGSize) -> CGSize {
        guard scale > 1.0 else { return .zero }
        let width = containerSize.width
        let height = containerSize.height
        let scaledWidth = width * scale
        let scaledHeight = height * scale
        let maxX = (scaledWidth - width) / 2
        let maxY = (scaledHeight - height) / 2
        let clampedX = min(max(offset.width, -maxX), maxX)
        let clampedY = min(max(offset.height, -maxY), maxY)
        return CGSize(width: clampedX, height: clampedY)
    }
}
