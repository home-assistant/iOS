#if !os(watchOS)
import HAIconic
import SwiftUI

/// A room: its picture, its name, what is worth knowing about it, and what can be switched from
/// here. The SwiftUI counterpart of the frontend's `hui-area-card`.
///
/// Presentational only. Which entities belong to an area, which of them count as alerts and which
/// are worth a control is the area registry's business and so the app's — the same split every
/// other card here makes.
public struct HAAreaCard: View {
    private static let pictureHeight: CGFloat = 140

    private let name: String
    private let picture: Image?
    private let icon: MaterialDesignIcons?
    /// The one-line readings across the foot — "3 lights on", "21.4 °C".
    private let sensors: [String]
    private let alerts: [HAAreaCardAlert]
    private let controls: [HAAreaCardControl]
    private let onTap: (() -> Void)?

    public init(
        name: String,
        picture: Image? = nil,
        icon: MaterialDesignIcons? = nil,
        sensors: [String] = [],
        alerts: [HAAreaCardAlert] = [],
        controls: [HAAreaCardControl] = [],
        onTap: (() -> Void)? = nil
    ) {
        self.name = name
        self.picture = picture
        self.icon = icon
        self.sensors = sensors
        self.alerts = alerts
        self.controls = controls
        self.onTap = onTap
    }

    public var body: some View {
        HACard {
            VStack(alignment: .leading, spacing: .zero) {
                // The card's own tap covers the picture and the summary only. Wrapping the whole
                // card would put a button around the control buttons: tapping a light would also
                // open the area, and VoiceOver would see buttons nested inside a button.
                VStack(alignment: .leading, spacing: .zero) {
                    header
                    summary
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap?() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(name))
                .accessibilityAddTraits(onTap == nil ? [] : .isButton)
                controlsRow
            }
        }
    }

    /// The picture with the alert badges over it, or — with no picture — the area's icon on a quiet
    /// fill. The frontend does the same, so a room without a photo is not a blank rectangle.
    private var header: some View {
        ZStack(alignment: .topTrailing) {
            if let picture {
                Color.clear
                    .overlay {
                        picture
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else {
                ZStack {
                    Color.haNeutralQuietFill
                    if let icon {
                        MaterialDesignIconsImage(icon: icon, size: 44)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !alerts.isEmpty {
                HStack(spacing: DesignSystem.Spaces.half) {
                    ForEach(alerts) { alert in
                        badge(alert)
                    }
                }
                .padding(DesignSystem.Spaces.one)
            }
        }
        .frame(height: Self.pictureHeight)
        .frame(maxWidth: .infinity)
    }

    private func badge(_ alert: HAAreaCardAlert) -> some View {
        HStack(spacing: DesignSystem.Spaces.micro) {
            MaterialDesignIconsImage(icon: alert.icon, size: 14)
            Text(alert.text)
                .font(.system(size: 12))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DesignSystem.Spaces.one)
        .padding(.vertical, DesignSystem.Spaces.micro)
        .background(alert.color)
        .clipShape(Capsule())
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            Text(name)
                .font(DesignSystem.Font.title3)
                .fixedSize(horizontal: false, vertical: true)
            if !sensors.isEmpty {
                Text(sensors.joined(separator: " · "))
                    .font(DesignSystem.Font.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spaces.two)
        .padding(.top, DesignSystem.Spaces.two)
        .padding(.bottom, controls.isEmpty ? DesignSystem.Spaces.two : DesignSystem.Spaces.one)
    }

    @ViewBuilder
    private var controlsRow: some View {
        if !controls.isEmpty {
            HStack(spacing: DesignSystem.Spaces.one) {
                ForEach(controls) { control in
                    controlButton(control)
                }
                Spacer(minLength: .zero)
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.bottom, DesignSystem.Spaces.two)
        }
    }

    private func controlButton(_ control: HAAreaCardControl) -> some View {
        Button(action: control.action) {
            MaterialDesignIconsImage(icon: control.icon, size: 20)
                .foregroundStyle(control.isActive ? Color.white : Color(uiColor: .label))
                .frame(width: 40, height: 40)
                .background(control.isActive ? Color.haPrimary : Color.haNeutralQuietFill)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(control.label))
        .accessibilityAddTraits(control.isActive ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAAreaCard(
            name: "Living room",
            icon: .sofaIcon,
            sensors: ["21.4 °C", "54 %"],
            alerts: [.init(id: "1", icon: .doorOpenIcon, text: "1", color: .haWarningColor)],
            controls: [
                .init(id: "light", icon: .lightbulbIcon, label: "Lights", isActive: true, action: {}),
                .init(id: "fan", icon: .fanIcon, label: "Fan", isActive: false, action: {}),
            ]
        )
        HAAreaCard(name: "Hallway", icon: .stairsIcon)
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAAreaCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-area-card" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
