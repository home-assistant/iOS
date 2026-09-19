import Foundation
import HAWatchComplications
import Shared

extension EnergyComplicationSnapshot {
    /// A payload for one of the app's servers, stamped with the time it was built.
    ///
    /// Lives here rather than in the complications package because that package deliberately knows
    /// nothing about `Server` — everything it holds has to compile in the widget extension, which
    /// links none of the networking stack.
    init(
        for server: Server,
        stats: [EnergyComplicationStat] = [],
        bars: [EnergyComplicationChartBar] = [],
        message: String? = nil
    ) {
        self.init(
            serverId: server.identifier.rawValue,
            serverName: server.info.name,
            date: Current.date(),
            stats: stats,
            bars: bars,
            message: message
        )
    }
}
