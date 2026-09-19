import Foundation

/// The resolved, target-agnostic rendering inputs for the energy complication.
///
/// The same seam the other complications have: the watch widget extension maps an
/// ``EnergyComplicationSnapshot`` into this, previews and tests build one directly, and
/// ``EnergyComplicationContentView`` is the only thing that knows how any of it is laid out.
public struct EnergyComplicationRenderModel: Equatable, Sendable {
    /// The period's headline figures, drawn above the chart in this order.
    public var stats: [EnergyComplicationStat]
    /// The period's buckets. Empty draws the chart's baseline alone rather than nothing at all, so a
    /// day that hasn't reported yet still looks like a chart waiting for data.
    public var bars: [EnergyComplicationChartBar]
    /// Shown above the figures when the app has more than one server, and nil otherwise: with a
    /// single server the name is the app's own and only costs a line the chart could use.
    public var serverName: String?
    /// Drawn instead of everything else — no energy dashboard on this server, or nothing reachable
    /// to read one from. Already localised by whoever built the model.
    public var message: String?

    public init(
        stats: [EnergyComplicationStat] = [],
        bars: [EnergyComplicationChartBar] = [],
        serverName: String? = nil,
        message: String? = nil
    ) {
        self.stats = stats
        self.bars = bars
        self.serverName = serverName
        self.message = message
    }

    /// Maps a stored snapshot onto the face.
    ///
    /// `showsServerName` is the caller's call rather than the snapshot's: whether the name is worth
    /// a line depends on how many servers the app has, which one snapshot can't see.
    public init(snapshot: EnergyComplicationSnapshot, showsServerName: Bool) {
        self.init(
            stats: snapshot.stats,
            bars: snapshot.bars,
            serverName: showsServerName ? snapshot.serverName : nil,
            message: snapshot.message
        )
    }
}
