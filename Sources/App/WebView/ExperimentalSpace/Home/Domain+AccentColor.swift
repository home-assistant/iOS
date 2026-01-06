import Foundation
import Shared
import SwiftUI

public extension Domain {
    var accentColor: Color {
        switch self {
        case .light:
            Color.Domain.light
        case .switch:
            Color.Domain.switch
        case .fan:
            Color.Domain.fan
        case .cover:
            Color.Domain.cover
        default:
            Color.haPrimary
        }
    }
}
