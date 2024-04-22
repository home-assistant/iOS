import Foundation
import WidgetKit

final class WidgetsSettingsViewModel: ObservableObject {
    @Published var isLoading = false

    func reloadWidgets() {
        isLoading = true
        WidgetCenter.shared.reloadAllTimelines()

        // Delay to give some sense of execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.isLoading = false
        }
    }
}
