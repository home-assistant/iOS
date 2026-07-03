import SFSafeSymbols
import Shared
import SwiftUI

/// Row content used by the on-watch configuration screens (the add picker and the edit-mode list).
/// It renders a `MagicItem` the same way the home rows do (circular icon + bold name) and can show an
/// optional context subtitle underneath (e.g. `Area • Device`) to mirror the iOS entity picker. It's
/// pure content with no tap handling, so callers wrap it in a `Button` or `NavigationLink`.
struct WatchConfigItemRow: View {
    let item: MagicItem
    let itemInfo: MagicItem.Info
    var subtitle: String? = nil
    var trailingSymbol: SFSymbol? = nil

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            icon
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(item.name(info: itemInfo))
                    .font(.body.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            if let trailingSymbol {
                Image(systemSymbol: trailingSymbol)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var iconColor: UIColor {
        if let hex = itemInfo.customization?.iconColor {
            .init(hex: hex)
        } else {
            .white
        }
    }

    private var icon: some View {
        Image(uiImage: item.icon(info: itemInfo).image(
            ofSize: .init(width: 24, height: 24),
            color: iconColor
        ))
        .frame(width: 38, height: 38)
        .modify { view in
            if #available(watchOS 26.0, *) {
                view.glassEffect(.clear.tint(Color(uiColor: iconColor).opacity(0.3)), in: .circle)
            } else {
                view
                    .background(Color(uiColor: iconColor).opacity(0.3))
                    .clipShape(Circle())
            }
        }
        .padding([.vertical, .trailing], DesignSystem.Spaces.half)
    }
}

/// Up/down reorder arrows shown on the trailing edge of a row while editing. Drag-to-reorder is
/// unreliable on watchOS, so these give an explicit way to move a row one position at a time.
struct WatchReorderControls: View {
    let upDisabled: Bool
    let downDisabled: Bool
    let onUp: () -> Void
    let onDown: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            control(symbol: .chevronUp, disabled: upDisabled, action: onUp)
            control(symbol: .chevronDown, disabled: downDisabled, action: onDown)
        }
        .font(.body.weight(.bold))
    }

    private func control(symbol: SFSymbol, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemSymbol: symbol)
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? Color.secondary.opacity(0.4) : Color.white)
        .disabled(disabled)
    }
}

extension View {
    /// Shared list-row background for the watch configuration rows.
    func watchConfigRowBackground() -> some View {
        listRowBackground(Color.gray.opacity(0.3).cornerRadius(14))
    }

    /// Matches the shape/material of the home item rows (`WatchMagicViewRow`): a glass pill on
    /// watchOS 26, a gray rounded row on older versions. Use on the action rows (add / entity /
    /// folder) so they look like the items.
    @ViewBuilder
    func watchItemRowStyle() -> some View {
        modify { view in
            if #available(watchOS 26.0, *) {
                view
                    .listRowBackground(Color.clear)
                    .buttonStyle(.glass)
            } else {
                view
                    .listRowBackground(Color.gray.opacity(0.3).cornerRadius(14))
            }
        }
    }
}
