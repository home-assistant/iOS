import Combine
import Foundation

enum MagicItemAddType {
    case scriptsScenesAutomations
    case entities
    case assistPipelines
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scriptsScenesAutomations
    @Published var selectedServerId: String?
}
