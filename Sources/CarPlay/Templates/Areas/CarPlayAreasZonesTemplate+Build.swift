#if canImport(CarPlay)
import Foundation

extension CarPlayAreasZonesTemplate {
    static func build() -> any CarPlayTemplateProvider {
        CarPlayAreasZonesTemplate(viewModel: .init())
    }
}
#endif
