import Foundation

extension CarPlayQuickAccessTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayQuickAccessTemplate(viewModel: .init())
    }
}
