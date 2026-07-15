import SFSafeSymbols
import Shared
import SwiftUI

/// The watch home screen's footer: app version and the edit + settings buttons.
/// Rendered as the last row of the home list.
struct WatchHomeFooterView: View {
    @ObservedObject var viewModel: WatchHomeViewModel
    let isEditing: Bool
    let onEdit: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(spacing: .zero) {
            appVersion
            HStack(spacing: DesignSystem.Spaces.one) {
                if !isEditing, !viewModel.watchConfig.items.isEmpty {
                    editFooterButton
                }
                settingsButton
            }
            .padding(DesignSystem.Spaces.one)
        }
        .listRowBackground(Color.clear)
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
