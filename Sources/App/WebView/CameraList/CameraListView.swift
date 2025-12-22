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
            .navigationTitle(L10n.CameraList.title)
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

            ForEach(viewModel.groupedCameras, id: \.area) { group in
                Section(header: Text(group.area)) {
                    ForEach(group.cameras, id: \.id) { camera in
                        Button(action: {
                            openCamera(camera)
                        }, label: {
                            CameraListRow(camera: camera)
                        })
                        .tint(.accentColor)
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchTerm, prompt: L10n.CameraList.searchPlaceholder)
        .onAppear {
            viewModel.fetchCameras()
        }
    }

    private var noCamerasView: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .videoSlash)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(L10n.CameraList.Empty.title)
                .font(.headline)
            Text(L10n.CameraList.Empty.message)
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
            Text(L10n.CameraList.NoResults.title)
                .font(.headline)
            Text(L10n.CameraList.NoResults.message)
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
    var body: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            Image(systemSymbol: .videoFill)
                .font(.title2)
                .foregroundStyle(.haPrimary)
                Text(camera.name)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
