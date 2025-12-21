import SFSafeSymbols
import Shared
import SwiftUI

struct CameraListView: View {
    @StateObject private var viewModel: CameraListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCamera: (camera: HAAppEntity, server: Server)?

    init(serverId: String? = nil) {
        self._viewModel = .init(wrappedValue: CameraListViewModel(serverId: serverId))
    }

    var body: some View {
        NavigationView {
            Group {
                if viewModel.filteredCameras.isEmpty, !viewModel.cameras.isEmpty {
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
        .fullScreenCover(item: Binding(
            get: { selectedCamera.map { CameraPresentation(camera: $0.camera, server: $0.server) } },
            set: { selectedCamera = $0.map { ($0.camera, $0.server) } }
        )) { presentation in
            WebRTCVideoPlayerView(
                server: presentation.server,
                cameraEntityId: presentation.camera.entityId
            )
        }
    }

    private var cameraListView: some View {
        List {
            if viewModel.shouldShowServerPicker {
                ServersPickerPillList(selectedServerId: $viewModel.selectedServerId)
            }

            ForEach(viewModel.filteredCameras, id: \.id) { camera in
                Button(action: {
                    openCamera(camera)
                }, label: {
                    CameraListRow(camera: camera, areaName: viewModel.areaName(for: camera))
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

        selectedCamera = (camera, server)
    }
}

// Helper struct to make camera presentation Identifiable
private struct CameraPresentation: Identifiable {
    let camera: HAAppEntity
    let server: Server

    var id: String { camera.id }
}

struct CameraListRow: View {
    let camera: HAAppEntity
    let areaName: String?

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .videoFill)
                .font(.title2)
                .foregroundStyle(.haPrimary)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(camera.name)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                HStack(spacing: DesignSystem.Spaces.half) {
                    if let areaName {
                        Text(areaName)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    } else {
                        Text(camera.entityId)
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
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
