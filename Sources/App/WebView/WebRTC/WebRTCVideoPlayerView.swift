import SFSafeSymbols
import Shared
import SwiftUI
import WebRTC

struct WebRTCVideoPlayerView: View {
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel: WebRTCViewPlayerViewModel

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var isPlaying: Bool = false
    @State private var isVideoPlaying: Bool = false

    private let server: Server
    private let cameraEntityId: String

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self._viewModel = .init(wrappedValue: WebRTCViewPlayerViewModel(server: server, cameraEntityId: cameraEntityId))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack(alignment: .topTrailing) {
                    player
                    controls
                }
                HAProgressView(style: .large)
                    .opacity(viewModel.showLoader ? 1.0 : 0.0)
                errorView
            }
            .background(.black)
            .statusBarHidden(true)
            .onAppear {
                viewModel.showControlsTemporarily()
            }
            .onDisappear {
                viewModel.hideControlsWorkItem?.cancel()
                viewModel.hideControlsWorkItem = nil
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

    private var errorView: some View {
        VStack {
            Image(systemSymbol: .exclamationmarkTriangle)
                .font(.title)
                .foregroundStyle(.white)
            Text(viewModel.failureReason ?? "")
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(viewModel.failureReason != nil ? 1.0 : 0.0)
        .animation(.easeInOut, value: viewModel.failureReason)
    }

    private func magnificationGesture(geometry: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = lastScale * value
                viewModel.showControlsTemporarily()
            }
            .onEnded { _ in
                lastScale = scale
                viewModel.showControlsTemporarily()
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
                viewModel.showControlsTemporarily()
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
                viewModel.showControlsTemporarily()
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
                viewModel.showControlsTemporarily()
            }
        }
    }

    private var player: some View {
        WebRTCVideoPlayerViewControllerWrapper(
            viewModel: viewModel,
            isVideoPlaying: $isVideoPlaying
        )
        .edgesIgnoringSafeArea(.all)
        .scaleEffect(.init(floatLiteral: scale >= 1.0 ? scale : 1.0))
        .offset(offset)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.showControlsTemporarily()
        }
    }

    private var controls: some View {
        WebRTCVideoPlayerViewControls(
            close: { dismiss() },
            isMuted: viewModel.isMuted,
            toggleMute: { viewModel.toggleMute() }
        )
        .transition(.opacity)
        .animation(.easeInOut, value: viewModel.controlsVisible)
        .opacity(viewModel.controlsVisible || !isVideoPlaying ? 1.0 : 0.0)
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

struct WebRTCVideoPlayerViewControllerWrapper: UIViewControllerRepresentable {
    private let viewModel: WebRTCViewPlayerViewModel
    @Binding var isVideoPlaying: Bool

    init(viewModel: WebRTCViewPlayerViewModel, isVideoPlaying: Binding<Bool>) {
        self.viewModel = viewModel
        self._isVideoPlaying = isVideoPlaying
    }

    func makeUIViewController(context: Context) -> WebRTCVideoPlayerViewController {
        let vc = WebRTCVideoPlayerViewController(viewModel: viewModel)
        vc.onVideoStarted = {
            isVideoPlaying = true
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCVideoPlayerViewController, context: Context) {
        /* no-op */
    }
}
