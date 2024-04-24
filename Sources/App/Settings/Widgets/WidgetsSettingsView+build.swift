import Foundation

extension WidgetsSettingsView {
    static func build() -> WidgetsSettingsView {
        let viewModel = WidgetsSettingsViewModel()
        return .init(viewModel: viewModel)
    }
}
