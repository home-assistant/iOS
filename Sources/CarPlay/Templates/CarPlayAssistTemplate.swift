import CarPlay
import Foundation
import HAKit
import Shared
import SwiftUI

@available(iOS 16.0, *)
enum CarPlayAssistState {
    case idle
    case listening
    case thinking
    case speaking
}

@available(iOS 16.0, *)
final class CarPlayAssistTemplate: CarPlayTemplateProvider {
    var state: CarPlayAssistState = .idle
    
    var template: CPInterfaceTemplate {
        let statusText: String
        let detailText: String?
        let image: CPImage?
        
        switch state {
        case .idle:
            statusText = "Assist"
            detailText = "Tap to start"
            image = CPImage(systemSymbol: .mic)
        case .listening:
            statusText = "Listening"
            detailText = "Speak your command"
            image = CPImage(systemSymbol: .waveform)
        case .thinking:
            statusText = "Thinking"
            detailText = "Processing..."
            image = CPImage(systemSymbol: .ellipsis)
        case .speaking:
            statusText = "Speaking"
            detailText = "Playing response"
            image = CPImage(systemSymbol: .speaker)
        }

        let item = CPListItem(text: statusText, detail: detailText, image: image)
        let section = CPListSection(items: [item])
        return CPInterfaceTemplate(templateFields: [section])
    }
    
    var interfaceController: CPInterfaceController?
    
    func entitiesStateChange(serverId: String, entities: HACachedStates) {}
    func update() {}

    @available(iOS 16.0, *)
    func mapViewModelToState(_ viewModel: AssistViewModel) -> CarPlayAssistState {
        if viewModel.isSpeaking {
            return .speaking
        } else if viewModel.isThinking {
            return .thinking
        } else if viewModel.isRecording {
            return .listening
        } else {
            return .idle
        }
    }
}
