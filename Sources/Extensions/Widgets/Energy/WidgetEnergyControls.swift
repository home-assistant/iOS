import Foundation
import Shared
import SwiftUI

/// The reload controls the Energy layouts hang their labels on.
///
/// The design system draws the period and the timestamp; both are the same control — a tap on either
/// reloads the widget's timeline — so this is what wraps them.
@available(iOS 17, *)
enum WidgetEnergyControls {
    /// Wraps the period label. The action, not the period, is what the control does, so that is what
    /// VoiceOver announces.
    static func period(_ title: String) -> (AnyView) -> AnyView {
        { label in
            AnyView(
                Button(intent: WidgetEnergyRefreshAppIntent()) {
                    label
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.Widgets.Energy.refreshTitle))
                .accessibilityValue(Text(verbatim: title))
            )
        }
    }

    /// Wraps the timestamp label. The visible text is a time, so name the action explicitly and
    /// leave the time as the value — otherwise VoiceOver announces a bare time with no hint of what
    /// tapping does.
    static func refresh(_ date: Date) -> (AnyView) -> AnyView {
        { label in
            AnyView(
                Button(intent: WidgetEnergyRefreshAppIntent()) {
                    label
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n.Widgets.Energy.refreshTitle))
                .accessibilityValue(Text(date, style: .time))
            )
        }
    }
}
