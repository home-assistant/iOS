import SFSafeSymbols
import Shared
import SwiftUI
import WebRTC

protocol AppCameraView {
    var controlsVisible: Binding<Bool> { get set }
    var showLoader: Binding<Bool> { get set }
}

struct WebRTCVideoPlayerView: View, AppCameraView {
    @Environment(\.dismiss) var dismiss

    @StateObject private var viewModel: WebRTCViewPlayerViewModel

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
        ZStack {
            ZoomableCameraContainer(
                onInteraction: {
                    showControlsTemporarily()
                },
                onSwipeDown: {
                    dismiss()
                },
                content: {
                    player
                }
            )
            errorView
        }
        .background(.black)
        .onAppear {
            showControlsTemporarily()
        }
        .onDisappear {
            hideControlsWorkItem?.cancel()
            hideControlsWorkItem = nil
        }
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

    private var player: some View {
        WebRTCVideoPlayerViewControllerWrapper(
            viewModel: viewModel,
            isVideoPlaying: $isVideoPlaying
        )
        .edgesIgnoringSafeArea(.all)
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
