#if !os(watchOS)
import HAIconic
import SwiftUI

/// A scene's more-info dialog: the scene's row with an "Activate" button, or its state while it is
/// unavailable. The SwiftUI counterpart of what the frontend shows for a scene: `state-card-scene`,
/// since the domain has no more-info control of its own.
public struct HAMoreInfoScene: View {
    private let name: String
    private let icon: MaterialDesignIcons
    private let color: Color
    private let lastChanged: Date
    private let now: Date
    private let unavailableState: String?
    private let onActivate: () -> Void

    /// - Parameter unavailableState: The state to show instead of the button ("Unavailable"), or
    ///   `nil` while the scene can be activated.
    public init(
        name: String,
        icon: MaterialDesignIcons = .paletteIcon,
        color: Color = .haPrimary,
        lastChanged: Date,
        now: Date,
        unavailableState: String? = nil,
        onActivate: @escaping () -> Void
    ) {
        self.name = name
        self.icon = icon
        self.color = color
        self.lastChanged = lastChanged
        self.now = now
        self.unavailableState = unavailableState
        self.onActivate = onActivate
    }

    public var body: some View {
        HAMoreInfoStateCard(
            name: name,
            icon: icon,
            color: unavailableState == nil ? color : .haDisabled,
            lastChanged: lastChanged,
            now: now
        ) {
            if let unavailableState {
                Text(unavailableState)
            } else {
                Button(HADesignSystemEnvironment.current.strings.sceneActivate, action: onActivate)
                    .foregroundStyle(Color.haPrimary)
            }
        }
    }
}

#Preview {
    VStack {
        HAMoreInfoScene(name: "Romantic scene", lastChanged: Date(timeIntervalSinceNow: -600), now: Date()) {}
        HAMoreInfoScene(
            name: "Romantic scene",
            lastChanged: Date(timeIntervalSinceNow: -2400),
            now: Date(),
            unavailableState: "Unavailable"
        ) {}
    }
    .padding()
}

extension HAMoreInfoScene: FrontendComponent {
    public static var frontendComponentName: String { "state-card-scene" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
