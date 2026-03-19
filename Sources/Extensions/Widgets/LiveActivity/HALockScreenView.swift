import ActivityKit
import Shared
import SwiftUI
import WidgetKit

/// Lock Screen (and StandBy) view for a Home Assistant Live Activity.
///
/// The system hard-truncates at 160 points height — padding counts against this limit.
/// Keep layout tight and avoid decorative spacing.
@available(iOS 16.2, *)
struct HALockScreenView: View {
    let attributes: HALiveActivityAttributes
    let state: HALiveActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row: icon + title
            HStack(spacing: 8) {
                iconView
                Text(attributes.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            // Body: timer or message
            if state.chronometer == true, let end = state.countdownEnd {
                Text(timerInterval: Date.now ... end, countsDown: true)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            } else {
                Text(state.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }

            // Progress bar (only when progress data is present)
            if let fraction = state.progressFraction {
                ProgressView(value: fraction)
                    .tint(accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var iconView: some View {
        if let iconSlug = state.icon {
            // UIColor(hex:) from Shared handles CSS names and 3/6/8-digit hex; non-failable.
            let uiColor = UIColor(hex: state.color ?? haBlueHex)
            let mdiIcon = MaterialDesignIcons(serversideValueNamed: iconSlug)
            Image(uiImage: mdiIcon.image(
                ofSize: .init(width: 20, height: 20),
                color: uiColor
            ))
            .resizable()
            .frame(width: 20, height: 20)
        }
    }

    // MARK: - Helpers

    /// Parse hex color from ContentState, fallback to Home Assistant blue.
    private var accentColor: Color {
        Color(hex: state.color ?? haBlueHex)
    }
}

// MARK: - Constants

/// Home Assistant brand blue — used as fallback for icon and progress bar tints.
let haBlueHex = "#03A9F4"
