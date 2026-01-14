import Combine
import Foundation
import GRDB
import HAKit
import PromiseKit
import Shared

enum MagicItemAddType {
    case scripts
    case actions
    case scenes
    case entities
}

final class MagicItemAddViewModel: ObservableObject {
    @Published var selectedItemType = MagicItemAddType.scripts
    @Published var actions: [Action] = []
    @Published var searchText: String = ""
    @Published var selectedServerId: String?

    @MainActor
    func loadContent() {
        loadActions()
    }

    @MainActor
    private func loadActions() {
        actions = Current.realm().objects(Action.self)
            .filter({ $0.Scene == nil })
            .sorted(by: { $0.Position < $1.Position })
    }
}
