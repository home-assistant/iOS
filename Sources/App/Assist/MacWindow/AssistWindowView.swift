import Foundation
import Shared
import SwiftUI

// When presented on macOS we use a separate WindowGroup
// This wrapper holds the Assist configuration while we still support
// iOS 15 and can't use the WindowGroup APIs to directly initialize
// using the correct configuration
struct AssistWindowView: View {
    @ObservedObject private var model = AssistWindowModel.shared

    var body: some View {
        if let server = model.server ?? Current.servers.all.first {
            AssistView.build(
                server: server,
                preferredPipelineId: model.preferredPipelineId,
                autoStartRecording: model.autoStartRecording,
                showCloseButton: false
            )
            .id(model.revision)
        }
    }
}

final class AssistWindowModel: ObservableObject {
    static let shared = AssistWindowModel()

    @Published private(set) var server: Server?
    @Published private(set) var preferredPipelineId = ""
    @Published private(set) var autoStartRecording = false
    /// Bumped on each `configure` so the Assist window builds a fresh session when reused for a new request.
    @Published private(set) var revision = 0

    func configure(server: Server, preferredPipelineId: String, autoStartRecording: Bool) {
        self.server = server
        self.preferredPipelineId = preferredPipelineId
        self.autoStartRecording = autoStartRecording
        revision += 1
    }
}
