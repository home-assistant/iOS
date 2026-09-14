import Combine
import Foundation
import Shared

@MainActor
final class VoiceToolsServerSettingsViewModel: ObservableObject {
    @Published var configuration: VoiceToolsServerConfiguration
    /// What the listener is doing, mirrored from the controller so the screen shows it live.
    @Published private(set) var state: WyomingServerState
    @Published private(set) var isSpeechRecognitionAuthorized: Bool

    /// `nil` in previews and snapshot tests, which have to show every state without opening a
    /// socket on the machine running them.
    private let controller: WyomingServerController?
    private var cancellables = Set<AnyCancellable>()

    /// None of the live values are defaulted here: default arguments are evaluated outside the main
    /// actor, and the controller lives on it. The screen's own initializer reads them.
    init(
        configuration: VoiceToolsServerConfiguration,
        controller: WyomingServerController?,
        state: WyomingServerState = .stopped,
        isSpeechRecognitionAuthorized: Bool = true
    ) {
        self.configuration = configuration
        self.controller = controller
        self.state = controller?.state ?? state
        self.isSpeechRecognitionAuthorized = isSpeechRecognitionAuthorized

        // No `receive(on:)`: the controller is `@MainActor`, so this already arrives on the main
        // actor, and hopping again would leave the status row a run-loop turn behind.
        controller?.$state
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &cancellables)

        // This screen owns the settings rather than editing a parent's copy, so it is also what
        // persists them and hands them to the controller, which starts, stops or rebinds the
        // listener to match.
        $configuration
            .dropFirst() // Skip the initial value set above
            .sink { [weak self] configuration in
                configuration.save()
                Task { @MainActor in
                    self?.controller?.applyConfiguration(configuration)
                }
            }
            .store(in: &cancellables)
    }

    /// Asked for when the server is switched on, so the prompt appears next to the explanation
    /// rather than during Home Assistant's first request with nothing on screen.
    func requestSpeechRecognitionAuthorization() async {
        isSpeechRecognitionAuthorized = await WyomingServerController.requestSpeechRecognitionAuthorization()
    }
}
