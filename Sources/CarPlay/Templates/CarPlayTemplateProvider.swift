import CarPlay
import Foundation
import HAKit

protocol CarPlayTemplateProvider {
    associatedtype Template: CPTemplate
    var template: Template { get set }
    var interfaceController: CPInterfaceController? { get set }
    func templateWillDisappear(template: CPTemplate)
    func templateWillAppear(template: CPTemplate)
    func entitiesStateChange(serverId: String, entities: HACachedStates)
    func update()
}
