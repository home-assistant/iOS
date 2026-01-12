import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 16.0, *)
struct CameraListView: View {
    @Namespace private var namespace
    @StateObject private var viewModel: CameraListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCamera: (camera: HAAppEntity, server: Server)?
    @State private var showSectionReorder = false
    @State private var selectedRoom: String?

    init(serverId: String? = nil) {
        self._viewModel = .init(wrappedValue: CameraListViewModel(serverId: serverId))
    }

    var body: some View {
        #if targetEnvironment(macCatalyst)
        macCatalystUnavailableView
        #else
        mainContent
        #endif
    }

    private var mainContent: some View {
        NavigationView {
            Group {
                if viewModel.filteredCameras.isEmpty, !viewModel.cameras.isEmpty {
                    emptySearchResultView
                } else if viewModel.cameras.isEmpty, viewModel.searchTerm.isEmpty {
                    noCamerasView
                } else {
                    cameraListView
                }
            }
            .navigationTitle(L10n.CameraList.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.cameras.isEmpty, viewModel.groupedCameras.count > 1 {
                        Button(action: {
                            showSectionReorder = true
                        }) {
                            Image(systemSymbol: .listDash)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $showSectionReorder) {
            CameraSectionReorderView(viewModel: viewModel)
        }
        .sheet(item: Binding(
            get: { selectedRoom.map { RoomPresentation(roomName: $0) } },
            set: { selectedRoom = $0?.roomName }
        )) { presentation in
            CamerasRoomView(viewModel: viewModel, areaName: presentation.roomName)
        }
        .fullScreenCover(item: Binding(
            get: { selectedCamera.map { CameraPresentation(camera: $0.camera, server: $0.server) } },
            set: { selectedCamera = $0.map { ($0.camera, $0.server) } }
        )) { presentation in
            WebRTCVideoPlayerView(
                server: presentation.server,
                cameraEntityId: presentation.camera.entityId,
                cameraName: presentation.camera.name
            )
            .modify { view in
                if #available(iOS 18.0, *) {
                    view.navigationTransition(.zoom(sourceID: presentation.camera.entityId, in: namespace))
                } else {
                    view
                }
            }
        }
    }

    private var macCatalystUnavailableView: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spaces.two) {
                Image(systemSymbol: .videoSlash)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(L10n.CameraList.Unavailable.title)
                    .font(.headline)
                Text(L10n.CameraList.Unavailable.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
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
    }

    private var cameraListView: some View {
        List {
            if viewModel.shouldShowServerPicker {
                ServersPickerPillList(selectedServerId: $viewModel.selectedServerId)
            }

            ForEach(viewModel.groupedCameras, id: \.area) { group in
                Section {
                    TabView {
                        ForEach(group.cameras, id: \.id) { camera in
                            CameraCardView(
                                serverId: camera.serverId,
                                entityId: camera.entityId,
                                cameraName: camera.name
                            )
                            .padding(.horizontal)
                            .padding(.top, DesignSystem.Spaces.one)
                            .onTapGesture {
                                openCamera(camera)
                            }
                            .modify { view in
                                if #available(iOS 18.0, *) {
                                    view.matchedTransitionSource(id: camera.entityId, in: namespace)
                                } else {
                                    view
                                }
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: .zero, leading: .zero, bottom: .zero, trailing: .zero))
                } header: {
                    Button(action: {
                        selectedRoom = group.area
                    }) {
                        HStack(spacing: DesignSystem.Spaces.one) {
                            Text(group.area)
                            Image(systemSymbol: .chevronRight)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
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

// Helper struct to make room presentation Identifiable
private struct RoomPresentation: Identifiable {
    let roomName: String

    var id: String { roomName }
}

@available(iOS 16.0, *)
#Preview {
    CameraListView()
}

@available(iOS 16.0, *)
#Preview("With Server ID") {
    CameraListView(serverId: "test-server")
}
