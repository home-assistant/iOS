import CarPlay
import Foundation

final class CarPlayAreasZonesTemplate: CarPlayTemplateProvider {
    var template: CPTemplate
    weak var interfaceController: CPInterfaceController?

    init() {
        self.template = CPTemplate()
    }

    func templateWillDisappear(template: CPTemplate) {}

    func templateWillAppear(template: CPTemplate) {}

    func update() {}
}
