import Foundation

@available(iOS 16.0, *)
extension CarPlayDomainsListTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayDomainsListTemplate(viewModel: .init())
    }
}
