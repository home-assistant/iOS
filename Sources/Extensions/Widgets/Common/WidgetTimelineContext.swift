import WidgetKit

/// The timeline inputs providers need, also constructible in tests without WidgetKit's host.
protocol WidgetTimelineContext {
    var family: WidgetFamily { get }
    var isPreview: Bool { get }
}

extension TimelineProviderContext: WidgetTimelineContext {}
