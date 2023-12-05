import Foundation

public protocol BiometricsViewModelDelegate: AnyObject {
    func didRequestUnlock()
}

@available(iOS 13.0, *)
final class BiometricsViewModel: ObservableObject {
    weak var delegate: BiometricsViewModelDelegate?

    func unlock() {
        delegate?.didRequestUnlock()
    }
}
