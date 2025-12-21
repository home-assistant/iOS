import SFSafeSymbols
import Shared
import SwiftUI

struct CameraListView: View {
    @StateObject private var viewModel: CameraListViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(serverId: String? = nil) {
        self._viewModel = .init(wrappedValue: CameraListViewModel(serverId: serverId))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.filteredCameras.isEmpty && !viewModel.cameras.isEmpty {
                    emptySearchResultView
                } else if viewModel.cameras.isEmpty {
                    noCamerasView
                } else {
                    cameraListView
                }
            }
            .navigationTitle("Cameras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var cameraListView: some View {
        List {
            ServersPickerPillList(selectedServerId: $viewModel.selectedServerId)
            
            ForEach(viewModel.filteredCameras, id: \.id) { camera in
                Button(action: {
                    openCamera(camera)
                }, label: {
                    CameraListRow(camera: camera)
                })
                .tint(.accentColor)
            }
        }
        .searchable(text: $viewModel.searchTerm, prompt: "Search cameras")
        .onAppear {
            viewModel.fetchCameras()
        }
    }

    private var noCamerasView: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .videoSlash)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Cameras")
                .font(.headline)
            Text("No camera entities found in your Home Assistant setup")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .onAppear {
            viewModel.fetchCameras()
        }
    }

    private var emptySearchResultView: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .magnifyingglass)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Results")
                .font(.headline)
            Text("No cameras match your search")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    private func openCamera(_ camera: HAAppEntity) {
        guard let server = viewModel.server(for: camera) else {
            Current.Log.error("No server found for camera: \(camera.entityId)")
            return
        }
        
        let view = WebRTCVideoPlayerView(
            server: server,
            cameraEntityId: camera.entityId
        ).embeddedInHostingController()
        view.modalPresentationStyle = .overFullScreen
        
        // Dismiss the list view first, then present the camera view
        dismiss()
        
        // Present the camera view from the root view controller
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                .done { webViewController in
                    webViewController.present(view, animated: true)
                }
        }
    }
}

struct CameraListRow: View {
    let camera: HAAppEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(camera.name)
                .font(.body)
                .foregroundStyle(Color.primary)
            Text(camera.entityId)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSystem.Spaces.half)
    }
}

#Preview {
    CameraListView()
}

#Preview("With Server ID") {
    CameraListView(serverId: "test-server")
}
