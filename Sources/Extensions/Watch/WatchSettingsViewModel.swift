import Combine
import Foundation
import Shared

final class WatchSettingsViewModel: ObservableObject {
    @Published private(set) var servers: [Server] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var assistPipelineTitle = L10n.Watch.Config.Assist.selectPipeline

    init() {
        Current.servers.add(observer: self)
        reload()
    }

    func reload() {
        let all = Current.servers.all
        let updatedAt = WatchUserDefaults.shared.date(for: .serversUpdatedAt)
        let assistPipelineTitle = Self.assistPipelineTitle()
        DispatchQueue.main.async { [weak self] in
            self?.servers = all
            self?.lastUpdated = updatedAt
            self?.assistPipelineTitle = assistPipelineTitle
        }
    }

    private static func assistPipelineTitle() -> String {
        guard let config = try? WatchConfig.config(),
              config.assist.showAssist,
              let pipelineId = config.assist.pipelineId else {
            return L10n.Watch.Config.Assist.selectPipeline
        }
        if pipelineId.isEmpty {
            return L10n.Watch.Config.Assist.preferred
        }
        return WatchUserDefaults.shared.assistPipelineName ?? pipelineId
    }
}

extension WatchSettingsViewModel: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        reload()
    }
}
