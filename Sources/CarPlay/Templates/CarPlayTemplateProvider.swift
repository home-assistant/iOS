import CarPlay
import Foundation
import HAKit

protocol CarPlayTemplateProvider {
    associatedtype Template: CPTemplate
    var template: Template { get set }
    var interfaceController: CPInterfaceController? { get set }
    /// Where this template's alerts and confirmations are presented. A requirement rather than only
    /// an extension member so an override dispatches dynamically.
    var alertPresenter: CarPlayAlertPresenting? { get }
    func templateWillDisappear(template: CPTemplate)
    func templateWillAppear(template: CPTemplate)
    func entitiesStateChange(serverId: String, entities: HACachedStates)
    func update()
}

extension CarPlayTemplateProvider {
    /// Defaults to CarPlay's own controller. `CPInterfaceController` has no public initializer, so
    /// templates whose confirmation flow is unit tested override this with a double.
    var alertPresenter: CarPlayAlertPresenting? { interfaceController }

    /// Tells the driver an action this template started didn't go through.
    func presentOperationFailure(_ error: CarPlayOperationError) {
        CarPlayOperationAlert.present(error, on: alertPresenter)
    }
}
