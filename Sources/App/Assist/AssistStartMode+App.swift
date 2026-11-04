import Foundation
import Shared

extension AssistStartMode {
    var localizedTitle: String {
        switch self {
        case .auto: return L10n.Assist.Settings.StartMode.auto
        case .voice: return L10n.Assist.Settings.StartMode.voice
        case .text: return L10n.Assist.Settings.StartMode.text
        }
    }
}
