import Combine
import Foundation

enum MagicItemAddType {
    case scripts
    case scenes
    case entities
    case assistPipelines
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scripts
    @Published var selectedServerId: String?
}
