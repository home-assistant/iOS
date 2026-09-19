import AppIntents
import WidgetKit

/// Which server's energy dashboard a complication summarises.
///
/// The user never has to answer it: the picker offers one ready-made complication per server, each
/// arriving with this already filled in. It exists so a face can still be pointed at a different
/// server after the fact, and so the choice survives the app adding or removing servers.
@available(watchOS 10.0, *)
struct WatchEnergyConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Energy"
    static let description = IntentDescription("Summarise a server's energy dashboard")

    @Parameter(title: "Server")
    var server: WatchEnergyServerEntity?

    init() {
        self.server = nil
    }

    init(server: WatchEnergyServerEntity) {
        self.server = server
    }

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}
