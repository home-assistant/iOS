import Foundation
import PromiseKit
import Shared

final class MagicItemCustomizationViewModel: ObservableObject {
    @Published var item: MagicItem
    @Published var info: MagicItem.Info?

    // Navigation action data
    @Published var navigationPathAction = ""

    // Assist action data
    @Published var selectedPipelineId: String?
    @Published var selectedServerIdForPipeline: String?
    @Published var startListeningAssistAction = true

    // Run script action data
    @Published var selectedEntity: HAAppEntity?

    private let itemProvider = Current.magicItemProvider()

    init(item: MagicItem) {
        self.item = item
    }

    @MainActor
    func loadMagicInfo() {
        itemProvider.loadInformation { [weak self] _ in
            guard let self else { return }
            loadInfo()
        }
    }

    @MainActor
    private func loadInfo() {
        info = itemProvider.getInfo(for: item)
    }
}
