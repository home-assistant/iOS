import Combine
import Foundation

final class AssistSettingsViewModel: ObservableObject {
    @Published var configuration: AssistConfiguration

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.configuration = AssistConfiguration.config

        $configuration
            .dropFirst() // Skip the initial value set in init
            .sink { config in
                config.save()
            }
            .store(in: &cancellables)
    }
}
