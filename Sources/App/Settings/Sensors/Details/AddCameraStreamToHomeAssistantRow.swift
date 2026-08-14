import Shared
import SwiftUI

/// The Camera Stream sensor's "Add to Home Assistant" row: one button that asks which server to
/// add the camera to (only when there is more than one) and then creates the MJPEG IP Camera
/// config entry with the stream URL and credentials already filled in.
struct AddCameraStreamToHomeAssistantRow: View {
    @StateObject private var viewModel = AddCameraStreamToHomeAssistantViewModel()
    @State private var isShowingServerPicker = false

    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Button(action: start) {
                HStack(spacing: DesignSystem.Spaces.one) {
                    Text(title)
                    if viewModel.isWorking {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.isAvailable || viewModel.isWorking)
            .confirmationDialog(
                L10n.Sensors.CameraStream.AddToHomeAssistant.chooseServer,
                isPresented: $isShowingServerPicker,
                titleVisibility: .visible
            ) {
                ForEach(viewModel.servers, id: \.identifier.rawValue) { server in
                    Button(server.info.name) {
                        viewModel.add(to: server)
                    }
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            }
            .alert(
                viewModel.didSucceed
                    ? L10n.Sensors.CameraStream.AddToHomeAssistant.successTitle
                    : L10n.Sensors.CameraStream.AddToHomeAssistant.failureTitle,
                isPresented: Binding(
                    get: { viewModel.resultMessage != nil },
                    set: { isPresented in
                        if !isPresented { viewModel.dismissResult() }
                    }
                ),
                actions: {
                    Button(L10n.okLabel) { viewModel.dismissResult() }
                },
                message: {
                    Text(viewModel.resultMessage ?? "")
                }
            )
            // Either what the button will do, or why it can't be tapped right now.
            Text(viewModel.unavailableReason ?? L10n.Sensors.CameraStream.AddToHomeAssistant.footer)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func start() {
        let servers = viewModel.servers
        if servers.count > 1 {
            isShowingServerPicker = true
        } else if let server = servers.first {
            viewModel.add(to: server)
        }
    }
}

#Preview {
    List {
        AddCameraStreamToHomeAssistantRow(title: "Add to Home Assistant")
    }
}
