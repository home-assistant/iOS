import Foundation

@available(iOSApplicationExtension 13.0, *)
extension BiometricsView {
    static func build(delegate: BiometricsViewModelDelegate) -> BiometricsView {
        let viewModel = BiometricsViewModel()
        let view = BiometricsView(viewModel: viewModel)
        viewModel.delegate = delegate
        return view
    }
}
