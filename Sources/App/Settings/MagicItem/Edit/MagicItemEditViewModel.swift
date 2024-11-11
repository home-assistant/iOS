import Foundation
import PromiseKit
import Shared

final class MagicItemEditViewModel: ObservableObject {
    @Published var item: MagicItem
    @Published var info: MagicItem.Info?

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
