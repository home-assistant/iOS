import CarPlay
import Foundation

protocol CarPlayTemplateProvider {
    var template: CPTemplate { get set }
    var interfaceController: CPInterfaceController? { get set }
    func templateWillDisappear(template: CPTemplate)
    func templateWillAppear(template: CPTemplate)
    func update()
}
