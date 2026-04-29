import Combine
import Foundation
import GRDB
import HAKit
import PromiseKit
import Shared

enum MagicItemAddType {
    case scripts
    case scenes
    case entities
    case assistPipelines
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scripts
    @Published var searchText: String = ""
    @Published var selectedServerId: String?
}
