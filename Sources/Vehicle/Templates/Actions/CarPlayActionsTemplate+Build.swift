import Foundation

extension CarPlayActionsTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayActionsTemplate(viewModel: .init())
    }
}
