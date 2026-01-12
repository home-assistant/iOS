import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 16.0, *)
struct CamerasRoomView: View {
    @Namespace private var namespace
    @ObservedObject var viewModel: CameraListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCamera: (camera: HAAppEntity, server: Server)?
    @State private var showInstructions = true

    let areaName: String

    init(viewModel: CameraListViewModel, areaName: String) {
        self.viewModel = viewModel
        self.areaName = areaName
    }

    private var cameras: [HAAppEntity] {
        viewModel.groupedCameras.first(where: { $0.area == areaName })?.cameras ?? []
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(cameras, id: \.id) { camera in
                        CameraCardView(serverId: camera.serverId, entityId: camera.entityId, cameraName: camera.name)
                            .frame(height: 220)
                            .padding(.horizontal, DesignSystem.Spaces.two)
                            .listRowInsets(.init(
                                top: DesignSystem.Spaces.one,
                                leading: .zero,
                                bottom: DesignSystem.Spaces.one,
                                trailing: .zero
                            ))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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
                    .onMove { source, destination in
                        viewModel.moveCameras(in: areaName, from: source, to: destination)
                    }
                } header: {
                    if showInstructions {
                        HStack {
                            Image(systemSymbol: .handDrawFill)
                                .foregroundStyle(.secondary)
                            Text(L10n.Cameras.dragToReorder)
                                .textCase(nil)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DesignSystem.Spaces.one)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(areaName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Hide instructions after 3 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation {
                        showInstructions = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .fullScreenCover(item: Binding(
            get: { selectedCamera.map { CameraPresentation(camera: $0.camera, server: $0.server) } },
            set: { selectedCamera = $0.map { ($0.camera, $0.server) } }
        )) { presentation in
            CameraPlayerView(
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

    private func openCamera(_ camera: HAAppEntity) {
        guard let server = viewModel.server(for: camera) else {
            Current.Log.error(L10n.Cameras.noServerFound(camera.entityId))
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

@available(iOS 16.0, *)
#Preview {
    let viewModel = CameraListViewModel()
    CamerasRoomView(viewModel: viewModel, areaName: "Living Room")
}
