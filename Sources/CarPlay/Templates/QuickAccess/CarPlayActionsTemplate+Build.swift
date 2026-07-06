import Foundation
import Shared

extension CarPlayQuickAccessTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayQuickAccessTemplate(viewModel: .init())
    }
}
