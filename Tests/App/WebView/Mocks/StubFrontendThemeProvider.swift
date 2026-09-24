import Shared
import SwiftUI

final class StubFrontendThemeProvider: FrontendThemeProviderProtocol {
    private var colorsByName: [String: Color] = [:]

    func set(_ color: Color, for frontendColor: FrontendColors) {
        colorsByName[frontendColor.rawValue] = color
    }

    func variables(for serverId: String?, appearance: FrontendThemeAppearance) -> [String: FrontendThemeVariable] {
        [:]
    }

    func value(of name: String, for serverId: String?, appearance: FrontendThemeAppearance) -> String? {
        nil
    }

    func color(of name: String, for serverId: String?) -> Color? {
        colorsByName[name]
    }

    func color(_ frontendColor: FrontendColors, for serverId: String?) -> Color {
        colorsByName[frontendColor.rawValue] ?? .clear
    }

    func store(_ variables: [FrontendThemeVariable], for serverId: String, appearance: FrontendThemeAppearance) {}

    func reload() {}
}
