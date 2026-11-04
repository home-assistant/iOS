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

    /// When this component was last reconciled with the frontend, as the date of the
    /// `home-assistant/frontend` commit it was checked against — `"2026-08-28"`.
    ///
    /// A port is only ever correct as of some frontend state, and without recording which, "is this
    /// still faithful?" can only be answered by re-reading the element. With it, the frontend's own
    /// history answers it: anything touching `ha-tip` after this component's date is a change this
    /// port has not seen.
    ///
    /// Dated rather than numbered because the frontend releases by date and its `package.json`
    /// carries a placeholder version. Deliberately **not** defaulted: a default would let a new
    /// component silently inherit a date nobody checked, which is the one thing this exists to
    /// prevent.
    ///
    /// Bump it when you reconcile the component against the frontend again — not when you merely
    /// edit it. A refactor that never opened the frontend has not made the port any newer.
    static var frontendComponentVersion: String { get }
}

public extension FrontendComponent {
    /// The name from an instance, so a value in a heterogeneous list can be asked without the
    /// caller having to name its type.
    var frontendComponentName: String { Self.frontendComponentName }

    /// The version from an instance, for the same reason.
    var frontendComponentVersion: String { Self.frontendComponentVersion }
}
