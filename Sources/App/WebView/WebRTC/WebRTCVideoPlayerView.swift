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

    private let server: Server
    private let cameraEntityId: String

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                WebRTCVideoPlayerViewControllerWrapper(
                    server: server,
                    cameraEntityId: cameraEntityId
                )
                .edgesIgnoringSafeArea(.all)
                .scaleEffect(.init(floatLiteral: scale >= 1.0 ? scale : 1.0))
                .offset(offset)
                .contentShape(Rectangle())
                .onTapGesture {
                    showControlsTemporarily()
                }
                WebRTCVideoPlayerViewControls {
                    dismiss()
                }
                .transition(.opacity)
                .opacity(controlsVisible ? 1.0 : 0.0)
            }
            .background(.black)
            .onAppear {
                showControlsTemporarily()
            }
            .gesture(
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
            )
            .simultaneousGesture(
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
                    .onEnded { _ in
                        guard scale > 1.0 else { return }
                        withAnimation(.spring()) {
                            offset = clampedOffset(for: offset, in: geometry.size)
                            lastOffset = offset
                        }
                        showControlsTemporarily()
                    }
            )
            .gesture(
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
            )
        }
    }

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

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    func makeUIViewController(context: Context) -> WebRTCVideoPlayerViewController {
        let vc = WebRTCVideoPlayerViewController(server: server, cameraEntityId: cameraEntityId)
        return vc
    }

    func updateUIViewController(_ uiViewController: WebRTCVideoPlayerViewController, context: Context) {
        /* no-op */
    }
}
