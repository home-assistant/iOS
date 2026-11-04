import SFSafeSymbols
import Shared
import SwiftUI

/// The watch home screen's footer: app version and the edit/done + settings buttons.
/// Rendered as the last row of the home list.
struct WatchHomeFooterView: View {
    @ObservedObject var viewModel: WatchHomeViewModel
    let isEditing: Bool
    let onEdit: () -> Void
    let onDone: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            appVersion
            HStack(spacing: DesignSystem.Spaces.one) {
                if isEditing {
                    // The header's Done is off screen once the list is scrolled to the bottom, which
                    // is exactly where reordering leaves you — so finishing is reachable from here too.
                    doneFooterButton
                } else if !viewModel.watchConfig.items.isEmpty {
                    editFooterButton
                }
                settingsButton
            }
            .padding(DesignSystem.Spaces.one)
        }
        .listRowBackground(Color.clear)
    }

    private var doneFooterButton: some View {
        Button {
            onDone()
        } label: {
            Image(systemSymbol: .checkmark)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground(tint: .haPrimary)
    }

    private var editFooterButton: some View {
        Button {
            onEdit()
        } label: {
            Image(systemSymbol: .pencil)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground()
    }

    private var settingsButton: some View {
        Button {
            onSettings()
        } label: {
            Image(systemSymbol: .gearshapeFill)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground()
        // Yellow attention dot: at least one server has no usable URL from the watch, so its magic
        // items can't run — settings hosts the per-server "Needs attention" warning explaining it.
        .overlay(alignment: .topTrailing) {
            if viewModel.settingsNeedsAttention {
                Circle()
                    .fill(.yellow)
                    .frame(width: 8, height: 8)
                    // Decorative: must not steal taps from the button or appear to VoiceOver.
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var appVersion: some View {
        VStack(alignment: .center, spacing: .zero) {
            Text(verbatim: AppConstants.version)
            Text(verbatim: "(\(AppConstants.build))")
                .font(DesignSystem.Font.caption3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
        .foregroundStyle(.secondary)
    }
}

#if DEBUG
#Preview {
    List {
        WatchHomeFooterView(
            viewModel: .init(),
            isEditing: false,
            onEdit: {},
            onDone: {},
            onSettings: {}
        )
    }
}

#Preview("Editing") {
    List {
        WatchHomeFooterView(
            viewModel: .init(),
            isEditing: true,
            onEdit: {},
            onDone: {},
            onSettings: {}
        )
    }
}
#endif
