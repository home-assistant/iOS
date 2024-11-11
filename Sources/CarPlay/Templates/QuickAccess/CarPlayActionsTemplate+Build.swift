import Foundation
import Shared

@available(iOS 16.0, *)
extension CarPlayQuickAccessTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayQuickAccessTemplate(viewModel: .init())
    }
}
