import SFSafeSymbols
import SwiftUI

/// A reusable vertical toggle control with a draggable thumb and glass effect
@available(iOS 26.0, *)
struct VerticalToggleControl: View {
    // MARK: - Configuration

    struct Configuration {
        var trackWidth: CGFloat = 120
        var trackHeight: CGFloat = 320
        var trackCornerRadius: CGFloat = 32
        var thumbSize: CGFloat = 100
        var thumbCornerRadius: CGFloat = 28
        var iconSize: CGFloat = 44
        var thumbPadding: CGFloat = 20
        var minimumDragDistance: CGFloat = 10
        var toggleThreshold: CGFloat = 30

        static let `default` = Configuration()
    }

    // MARK: - Properties

    @Binding var isOn: Bool
    var icon: SFSymbol
    var accentColor: Color
    var isDisabled: Bool
    var configuration: Configuration
    var onToggle: (() -> Void)?

    @State private var isDragging = false
    @State private var dragOffset: CGFloat = 0
    @State private var triggerHaptic = 0

    // MARK: - Initialization

    /// Creates a vertical toggle control
    /// - Parameters:
    ///   - isOn: Binding to the toggle state
    ///   - icon: SF Symbol to display in the thumb
    ///   - accentColor: Color for the active state (defaults to system accent)
    ///   - isDisabled: Whether the control is disabled
    ///   - configuration: Visual configuration for the control
    ///   - onToggle: Optional callback when the toggle state changes
    init(
        isOn: Binding<Bool>,
        icon: SFSymbol = .powerCircle,
        accentColor: Color = .accentColor,
        isDisabled: Bool = false,
        configuration: Configuration = .default,
        onToggle: (() -> Void)? = nil
    ) {
        self._isOn = isOn
        self.icon = icon
        self.accentColor = accentColor
        self.isDisabled = isDisabled
        self.configuration = configuration
        self.onToggle = onToggle
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Track background with glass effect
            RoundedRectangle(cornerRadius: configuration.trackCornerRadius, style: .continuous)
                .fill(Color(uiColor: .secondarySystemFill))
                .frame(width: configuration.trackWidth, height: configuration.trackHeight)
                .glassEffect(
                    .clear,
                    in: RoundedRectangle(cornerRadius: configuration.trackCornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: configuration.trackCornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )

            // Animated thumb
            thumb
                .offset(y: thumbOffset)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isOn)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                            }
                            // Clamp drag offset to track bounds
                            let availableTravel = configuration.trackHeight - configuration
                                .thumbSize - (configuration.thumbPadding * 2)
                            let maxOffset = availableTravel / 2
                            dragOffset = min(max(gesture.translation.height, -maxOffset), maxOffset)
                        }
                        .onEnded { gesture in
                            let translation = gesture.translation.height

                            // If minimal movement, treat as tap
                            if abs(translation) < configuration.minimumDragDistance {
                                performToggle()
                            } else {
                                // Determine if we should toggle based on drag direction and distance
                                if abs(translation) > configuration.toggleThreshold {
                                    if translation < 0, !isOn {
                                        // Dragged up and currently off -> turn on
                                        performToggle()
                                    } else if translation > 0, isOn {
                                        // Dragged down and currently on -> turn off
                                        performToggle()
                                    }
                                }
                            }

                            isDragging = false
                            dragOffset = 0
                        }
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
        .sensoryFeedback(.impact, trigger: triggerHaptic)
    }

    // MARK: - Thumb

    private var thumb: some View {
        RoundedRectangle(cornerRadius: configuration.thumbCornerRadius, style: .continuous)
            .fill(isOn ? accentColor : Color(uiColor: .systemBackground))
            .frame(width: configuration.thumbSize, height: configuration.thumbSize)
            .shadow(
                color: isOn ? accentColor.opacity(0.4) : Color.black.opacity(0.15),
                radius: isOn ? 12 : 8,
                x: 0,
                y: isOn ? 6 : 4
            )
            .overlay(
                Image(systemSymbol: icon)
                    .font(.system(size: configuration.iconSize, weight: .semibold))
                    .foregroundStyle(isOn ? .white : accentColor)
            )
            .scaleEffect(isDragging ? 0.95 : 1.0)
    }

    // MARK: - Computed Properties

    private var thumbOffset: CGFloat {
        let availableTravel = configuration.trackHeight - configuration.thumbSize - (configuration.thumbPadding * 2)
        let baseOffset = isOn ? -(availableTravel / 2) : (availableTravel / 2)

        // Add drag offset when dragging
        return baseOffset + dragOffset
    }

    // MARK: - Actions

    private func performToggle() {
        triggerHaptic += 1
        isOn.toggle()
        onToggle?()
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
#Preview("Vertical Toggle - On") {
    @Previewable @State var isOn = true

    VStack {
        Text(isOn ? "On" : "Off")
            .font(.title)

        VerticalToggleControl(
            isOn: $isOn,
            icon: .powerCircle,
            accentColor: .blue
        )
    }
    .padding()
}

@available(iOS 26.0, *)
#Preview("Vertical Toggle - Off") {
    @Previewable @State var isOn = false

    VStack {
        Text(isOn ? "On" : "Off")
            .font(.title)

        VerticalToggleControl(
            isOn: $isOn,
            icon: .powerCircle,
            accentColor: .green
        )
    }
    .padding()
}

@available(iOS 26.0, *)
#Preview("Vertical Toggle - Custom Icon") {
    @Previewable @State var isOn = false

    VStack {
        Text(isOn ? "Light On" : "Light Off")
            .font(.title)

        VerticalToggleControl(
            isOn: $isOn,
            icon: .lightbulb,
            accentColor: .yellow
        )
    }
    .padding()
}

@available(iOS 26.0, *)
#Preview("Vertical Toggle - Disabled") {
    @Previewable @State var isOn = true

    VStack {
        Text("Disabled State")
            .font(.title)

        VerticalToggleControl(
            isOn: $isOn,
            icon: .powerCircle,
            accentColor: .red,
            isDisabled: true
        )
    }
    .padding()
}
