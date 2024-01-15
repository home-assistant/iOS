import Foundation

@available(iOS 16.0, *)
extension CarPlayServersListTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayServersListTemplate(viewModel: .init())
    }
}
