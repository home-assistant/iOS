import CarPlay
import Combine
import Foundation
import HAKit
import SFSafeSymbols
import Shared

@available(iOS 16.0, *)
enum CarPlayAssistState: String {
    case idle
    case listening
    case thinking
    case speaking
}

@available(iOS 16.0, *)
final class CarPlayAssistTemplate: CarPlayTemplateProvider {
    private let viewModel: AssistViewModel
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedSession = false

    var state: CarPlayAssistState = .idle {
        didSet {
            guard oldValue != state else { return }
            template.updateGridButtons([Self.statusButton(for: state)])
        }
    }

    var template: CPGridTemplate
    weak var interfaceController: CPInterfaceController?

    init(viewModel: AssistViewModel) {
        self.viewModel = viewModel
        self.template = CPGridTemplate(
            title: L10n.Assist.ModernUi.Header.title,
            gridButtons: [Self.statusButton(for: .idle)]
        )
        bindViewModel()
    }

    func templateWillDisappear(template: CPTemplate) {
        guard template == self.template else { return }
        viewModel.onDisappear()
    }

    func templateWillAppear(template: CPTemplate) {
        guard template == self.template else { return }
        guard !hasStartedSession else { return }

        hasStartedSession = true
        viewModel.subscribeForConfigChanges()
        Task { @MainActor [weak self] in
            self?.viewModel.initialRoutine()
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {}

    func update() {}

    private func bindViewModel() {
        viewModel.$isRecording
            .combineLatest(viewModel.$isThinking, viewModel.$isSpeaking)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, isThinking, isSpeaking in
                self?.state = Self.mapState(
                    isRecording: isRecording,
                    isThinking: isThinking,
                    isSpeaking: isSpeaking
                )
            }
            .store(in: &cancellables)
    }

    private static func mapState(
        isRecording: Bool,
        isThinking: Bool,
        isSpeaking: Bool
    ) -> CarPlayAssistState {
        if isSpeaking {
            return .speaking
        } else if isThinking {
            return .thinking
        } else if isRecording {
            return .listening
        } else {
            return .idle
        }
    }

    private static func statusButton(for state: CarPlayAssistState) -> CPGridButton {
        let title: String
        let image: UIImage

        switch state {
        case .idle:
            title = L10n.Assist.ModernUi.Header.title
            image = UIImage(systemSymbol: .micFill)
        case .listening:
            title = L10n.Assist.Button.Listening.title
            image = UIImage(systemSymbol: .waveform)
        case .thinking:
            title = L10n.CarPlay.State.Loading.title
            image = UIImage(systemSymbol: .ellipsis)
        case .speaking:
            title = L10n.Assist.ModernUi.Header.title
            image = UIImage(systemSymbol: .speakerWave2Fill)
        }

        return CPGridButton(
            titleVariants: [title],
            image: image,
            handler: nil
        )
    }
}
