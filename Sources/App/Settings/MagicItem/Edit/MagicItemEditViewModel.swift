import Foundation
import PromiseKit
import Shared

final class MagicItemEditViewModel: ObservableObject {
    @Published var item: MagicItem
    @Published var info: MagicItem.Info?

    init(item: MagicItem) {
        self.item = item
    }

    func loadMagicInfo() {
        let itemProvider = Current.magicItemProvider()
        itemProvider.loadInformation { [weak self] in
            guard let self else { return }
            info = itemProvider.getInfo(for: item)
        }
    }
}
