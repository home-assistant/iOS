import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
extension CarPlayEntitiesListTemplate {
    static func build(
        title: String,
        filterType: CarPlayEntitiesListViewModel.FilterType,
        server: Server,
        entitiesCachedStates: HACachedStates
    ) -> CarPlayEntitiesListTemplate {
        let viewModel = CarPlayEntitiesListViewModel(
            filterType: filterType,
            server: server,
            entitiesCachedStates: entitiesCachedStates
        )

        return CarPlayEntitiesListTemplate(viewModel: viewModel, title: title)
    }
}
