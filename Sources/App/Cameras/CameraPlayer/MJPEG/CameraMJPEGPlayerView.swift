import Shared
import SwiftUI
import UIKit

/// A SwiftUI view for displaying MJPEG camera streams.
@available(iOS 16.0, *)
struct CameraMJPEGPlayerView: View {
    @StateObject private var viewModel: CameraMJPEGPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?

    init(server: Server, cameraEntityId: String, cameraName: String? = nil) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
        _viewModel = StateObject(wrappedValue: CameraMJPEGPlayerViewModel(
            server: server,
            cameraEntityId: cameraEntityId
        ))
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if viewModel.errorMessage == nil {
                if let uiImage = viewModel.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                        .animation(.easeInOut, value: uiImage)
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
            VStack {
                HStack {
                    if let cameraName {
                        Text(cameraName)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemSymbol: .xmark)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
            }

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }

            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemSymbol: .exclamationmarkTriangle)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text(errorMessage)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

#if DEBUG
@available(iOS 16.0, *)
#Preview {
    CameraMJPEGPlayerView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
