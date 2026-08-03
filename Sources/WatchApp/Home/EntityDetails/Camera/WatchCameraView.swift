import AVFoundation
import AVKit
import SFSafeSymbols
import Shared
import SwiftUI

/// The screen a camera row opens: the entity's live stream, loaded the same way the watch's camera
/// notifications load theirs — the server's HLS stream when there is one, the MJPEG proxy
/// otherwise (see `WatchCameraViewModel`).
struct WatchCameraView: View {
    @StateObject private var viewModel: WatchCameraViewModel

    init(viewModel: WatchCameraViewModel) {
        self._viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            switch viewModel.stream {
            case let .hls(player):
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
            case let .mjpeg(image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            case nil:
                EmptyView()
            }
            if viewModel.isLoading {
                VStack(spacing: DesignSystem.Spaces.half) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text(verbatim: L10n.Watch.Camera.connecting)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let errorMessage = viewModel.errorMessage {
                ScrollView {
                    VStack(spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: .exclamationmarkTriangle)
                            .font(.title3)
                            .foregroundStyle(.orange)
                        Text(verbatim: errorMessage)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                        if let errorDetail = viewModel.errorDetail {
                            Text(verbatim: errorDetail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Button {
                            viewModel.retry()
                        } label: {
                            Text(verbatim: L10n.retryLabel)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spaces.one)
                }
            }
        }
        .navigationTitle(Text(verbatim: viewModel.name))
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

#if DEBUG
#Preview("Streaming") {
    UIGraphicsBeginImageContextWithOptions(CGSize(width: 320, height: 180), true, 1)
    UIColor.darkGray.setFill()
    UIRectFill(CGRect(x: 0, y: 0, width: 320, height: 180))
    UIColor.cyan.setFill()
    UIRectFill(CGRect(x: 120, y: 50, width: 80, height: 80))
    let frame = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    UIGraphicsEndImageContext()
    return NavigationStack {
        WatchCameraView(viewModel: .preview(name: "Front door", stream: .mjpeg(frame)))
    }
}

#Preview("Connecting") {
    NavigationStack {
        WatchCameraView(viewModel: .preview(name: "Front door", isLoading: true))
    }
}

#Preview("Error") {
    NavigationStack {
        WatchCameraView(viewModel: .preview(
            name: "Front door",
            errorMessage: L10n.CameraPlayer.Errors.unableToConnectToServer,
            errorDetail: L10n.Watch.Camera.Error.hls(L10n.CameraPlayer.Errors.noStreamAvailable)
        ))
    }
}
#endif
