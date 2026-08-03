import Combine
import Foundation

enum MagicItemAddType {
    case entities
    case areas
    case assistPipelines
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType: MagicItemAddType
    @Published var selectedServerId: String?

    init(selectedItemType: MagicItemAddType) {
        self.selectedItemType = selectedItemType
    }
}
