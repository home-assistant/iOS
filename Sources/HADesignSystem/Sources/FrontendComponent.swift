import Foundation

/// A design-system type that is the counterpart of a component in `home-assistant/frontend`.
///
/// The mapping used to live only in doc comments, which meant nothing could check it. Declaring it
/// as a conformance makes it data: the gallery can show which element a component came from, and a
/// test can assert that every component in the library declares one and that the names are
/// well-formed and not accidentally shared.
///
/// **Conform only what is actually a port.** Components with no frontend counterpart —
/// `FullScreenLoaderView`, `LabsLabel`, `PrivacyNoteView` and the rest of the app's own chrome —
/// deliberately do not conform, and that absence is itself the mapping. Their doc comments say
/// "Frontend counterpart: none" and why.
public protocol FrontendComponent {
    /// The frontend custom element this corresponds to, spelled exactly as its `@customElement`
    /// tag: `"ha-tip"`, `"hui-tile-card"`, `"hui-clock-card-analog"`.
    ///
    /// A few components correspond to a *file* rather than a registered element — the chart modules
    /// under `src/components/chart/` are imported directly. Those use the module's name, which is
    /// what the frontend calls them: `"state-history-chart-line"`.
    static var frontendComponentName: String { get }
}

public extension FrontendComponent {
    /// The name from an instance, so a value in a heterogeneous list can be asked without the
    /// caller having to name its type.
    var frontendComponentName: String { Self.frontendComponentName }
}
