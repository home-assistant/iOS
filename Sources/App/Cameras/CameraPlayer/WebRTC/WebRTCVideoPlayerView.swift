import SFSafeSymbols
import Shared
import SwiftUI
import WebRTC

protocol AppCameraView {
    var controlsVisible: Binding<Bool> { get set }
    var showLoader: Binding<Bool> { get set }
}

@available(iOS 16.0, *)
struct WebRTCVideoPlayerView: View, AppCameraView {
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel: WebRTCViewPlayerViewModel

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var previousFrameScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var isPlaying: Bool = false
    @State private var isVideoPlaying: Bool = false
    var controlsVisible: Binding<Bool>
    var showLoader: Binding<Bool>
    @State var hideControlsWorkItem: DispatchWorkItem?

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?
    private let onWebRTCUnsupported: (() -> Void)?

    init(
        server: Server,
        cameraEntityId: String,
        cameraName: String? = nil,
        controlsVisible: Binding<Bool>,
        showLoader: Binding<Bool>,
        onWebRTCUnsupported: (() -> Void)? = nil
    ) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
        self.onWebRTCUnsupported = onWebRTCUnsupported
        self.controlsVisible = controlsVisible
        self.showLoader = showLoader
        self._viewModel = .init(wrappedValue: WebRTCViewPlayerViewModel(server: server, cameraEntityId: cameraEntityId))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                player
                errorView
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
            .background(.black)
            .onAppear {
                showControlsTemporarily()
            }
            .onDisappear {
                hideControlsWorkItem?.cancel()
                hideControlsWorkItem = nil
            }
            .simultaneousGesture(
                dragGesture(geometry: geometry)
            )
            .onTapGesture {
                showControlsTemporarily()
            }
            .onChange(of: viewModel.isWebRTCUnsupported) { isUnsupported in
                if isUnsupported {
                    onWebRTCUnsupported?()
                }
            }
            .onChange(of: viewModel.showLoader) { showLoader in
                self.showLoader.wrappedValue = showLoader
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if controlsVisible.wrappedValue {
                    Button(action: {
                        viewModel.toggleMute()
                    }) {
                        Image(systemSymbol: viewModel.isMuted ? .speakerSlashFill : .speakerWave3)
                    }
                }
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
        showControlsTemporarily()
    }

    private func handlePinchEnded(in containerSize: CGSize) {
        lastScale = scale
        previousFrameScale = scale
        showControlsTemporarily()
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
            showControlsTemporarily()
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

    private var player: some View {
        WebRTCVideoPlayerViewControllerWrapper(
            viewModel: viewModel,
            isVideoPlaying: $isVideoPlaying
        )
        .edgesIgnoringSafeArea(.all)
        .scaleEffect(.init(floatLiteral: scale >= 1.0 ? scale : 1.0))
        .offset(offset)
    }

    private func showControlsTemporarily() {
        controlsVisible.wrappedValue = true
        hideControlsWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            controlsVisible.wrappedValue = false
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
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

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> WebRTCVideoPlayerViewController {
        let vc = WebRTCVideoPlayerViewController(viewModel: viewModel)
        vc.onVideoStarted = { [weak coordinator = context.coordinator] in
            coordinator?.videoDidStart()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCVideoPlayerViewController, context: Context) {
        /* no-op */
    }

    class Coordinator {
        var parent: WebRTCVideoPlayerViewControllerWrapper

        init(parent: WebRTCVideoPlayerViewControllerWrapper) {
            self.parent = parent
        }

        func videoDidStart() {
            parent.isVideoPlaying = true
        }
    }
}
