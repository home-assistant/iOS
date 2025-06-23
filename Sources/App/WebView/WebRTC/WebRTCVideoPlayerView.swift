import Shared
import SwiftUI
import WebRTC

struct WebRTCVideoPlayerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var isPlaying: Bool = false
    @State private var controlsVisible: Bool = true
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var isVideoPlaying: Bool = false

    private let server: Server
    private let cameraEntityId: String

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                player
                controls
            }
            .background(.black)
            .statusBarHidden(true)
            .onAppear {
                showControlsTemporarily()
            }
            .gesture(
                magnificationGesture(geometry: geometry)
            )
            .simultaneousGesture(
                dragGesture(geometry: geometry)
            )
            .gesture(
                tapGesture
            )
        }
        .modify { view in
            if #available(iOS 16.0, *) {
                view.persistentSystemOverlays(.hidden)
            } else {
                view
            }
        }
    }

    private func magnificationGesture(geometry: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
                showControlsTemporarily()
            }
            .onEnded { _ in
                lastScale = scale
                showControlsTemporarily()
                if scale <= 1.0 {
                    withAnimation {
                        offset = .zero
                        lastOffset = .zero
                    }
                } else {
                    withAnimation {
                        offset = clampedOffset(for: offset, in: geometry.size)
                        lastOffset = offset
                    }
                }
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
                showControlsTemporarily()
            }
            .onEnded { value in
                // If user is not zoomed in, allow dismissing the view with a swipe down
                guard scale > 1.0 else {
                    if value.translation.height > 100 {
                        dismiss()
                    }
                    return
                }
                withAnimation(.spring()) {
                    offset = clampedOffset(for: offset, in: geometry.size)
                    lastOffset = offset
                }
                showControlsTemporarily()
            }
    }

    private var tapGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation {
                if scale > 1.0 {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    scale = 2.0
                    lastScale = 2.0
                }
                showControlsTemporarily()
            }
        }
    }

    private var player: some View {
        WebRTCVideoPlayerViewControllerWrapper(
            server: server,
            cameraEntityId: cameraEntityId,
            isVideoPlaying: $isVideoPlaying
        )
        .edgesIgnoringSafeArea(.all)
        .scaleEffect(.init(floatLiteral: scale >= 1.0 ? scale : 1.0))
        .offset(offset)
        .contentShape(Rectangle())
        .onTapGesture {
            showControlsTemporarily()
        }
    }

    private var controls: some View {
        WebRTCVideoPlayerViewControls {
            dismiss()
        }
        .transition(.opacity)
        .opacity(controlsVisible || !isVideoPlaying ? 1.0 : 0.0)
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

    private func showControlsTemporarily() {
        controlsVisible = true
        hideControlsWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation {
                controlsVisible = false
            }
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }
}

struct WebRTCVideoPlayerViewControllerWrapper: UIViewControllerRepresentable {
    private let server: Server
    private let cameraEntityId: String
    @Binding var isVideoPlaying: Bool

    init(server: Server, cameraEntityId: String, isVideoPlaying: Binding<Bool>) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self._isVideoPlaying = isVideoPlaying
    }

    func makeUIViewController(context: Context) -> WebRTCVideoPlayerViewController {
        let vc = WebRTCVideoPlayerViewController(server: server, cameraEntityId: cameraEntityId)
        vc.onVideoStarted = {
            isVideoPlaying = true
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCVideoPlayerViewController, context: Context) {
        /* no-op */
    }
}
