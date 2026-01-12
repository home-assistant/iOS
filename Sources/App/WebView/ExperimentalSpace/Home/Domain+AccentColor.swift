import Foundation
import Shared
import SwiftUI

public extension Domain {
    var accentColor: Color {
        switch self {
        case .climate:
            Color.Domain.climate
        case .light:
            Color.Domain.light
        case .switch:
            Color.Domain.switch
        case .fan:
            Color.Domain.fan
        case .cover:
            Color.Domain.cover
        case .lock:
            Color.Domain.lock
        case .inputBoolean:
            Color.Domain.inputBoolean
        default:
            Color.haPrimary
        }
    }
}
