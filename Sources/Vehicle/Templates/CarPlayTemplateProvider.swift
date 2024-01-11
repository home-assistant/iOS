import CarPlay
import Foundation

protocol CarPlayTemplateProvider {
    associatedtype Template: CPTemplate
    var template: Template { get set }
    var interfaceController: CPInterfaceController? { get set }
    func templateWillDisappear(template: CPTemplate)
    func templateWillAppear(template: CPTemplate)
    func update()
}
