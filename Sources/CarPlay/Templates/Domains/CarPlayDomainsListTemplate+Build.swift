import Foundation

extension CarPlayDomainsListTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayDomainsListTemplate(viewModel: .init())
    }
}
