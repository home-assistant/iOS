import Foundation

@available(iOS 16.0, *)
extension CarPlayAreasZonesTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayAreasZonesTemplate(viewModel: .init())
    }
}
