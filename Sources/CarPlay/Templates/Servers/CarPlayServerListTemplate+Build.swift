import Foundation

extension CarPlayServersListTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayServersListTemplate(viewModel: .init())
    }
}
