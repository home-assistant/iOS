import SFSafeSymbols
import Shared
import SwiftUI

/// The watch home screen's fake navigation header: reload + loading + Assist, or a Done button while
/// editing. Rendered as the first row of the home list.
struct WatchHomeHeaderView: View {
    @ObservedObject var viewModel: WatchHomeViewModel
    @Binding var isEditing: Bool
    let onAssist: () -> Void

    private enum Constants {
        static let headerButtonSize: CGFloat = DesignSystem.Spaces.five
        static let headerCenterSpacer: CGFloat = DesignSystem.Spaces.one
    }

    var body: some View {
        HStack {
            if isEditing {
                doneButton
                Spacer()
            } else {
                // Leading: reload
                navReloadButton
                    .frame(
                        width: Constants.headerButtonSize,
                        height: Constants.headerButtonSize,
                        alignment: .center
                    )

                // Center: loading state stays centered
                Spacer(minLength: Constants.headerCenterSpacer)
                toolbarLoadingState
                Spacer(minLength: Constants.headerCenterSpacer)

                // Trailing: Assist (reserves space when Assist isn't configured)
                assistHeaderButton
                    .frame(width: Constants.headerButtonSize, height: Constants.headerButtonSize, alignment: .center)
            }
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
    }

    private var doneButton: some View {
        Button {
            withAnimation { isEditing = false }
            viewModel.saveConfig()
        } label: {
            Image(systemSymbol: .checkmark)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground(tint: .haPrimary)
    }

    private var navReloadButton: some View {
        Button {
            viewModel.requestConfig()
        } label: {
            Image(systemSymbol: .arrowCounterclockwise)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground()
    }

    @ViewBuilder
    private var toolbarLoadingState: some View {
        HStack {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .circularGlassOrLegacyBackground()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var assistHeaderButton: some View {
        if viewModel.showAssist {
            assistButton
                .modify { view in
                    if #available(watchOS 11, *) {
                        view.handGestureShortcut(.primaryAction)
                    } else {
                        view
                    }
                }
                .circularGlassOrLegacyBackground(tint: .haPrimary)
        } else {
            // Reserve space to keep the loader centered
            Rectangle()
                .foregroundStyle(Color.clear)
                .frame(width: 44, height: 44)
        }
    }

    private var assistButton: some View {
        Button(action: onAssist, label: {
            let color: UIColor = {
                if #available(watchOS 26.0, *) {
                    return .white
                } else {
                    return UIColor(Color.haPrimary)
                }
            }()
            Image(uiImage: MaterialDesignIcons.messageProcessingOutlineIcon.image(
                ofSize: .init(width: 24, height: 24),
                color: color
            ))
        })
        .buttonStyle(.plain)
        .modify { view in
            if #available(watchOS 26.0, *) {
                view
                    .tint(.haPrimary)
            } else {
                view
            }
        }
    }
}
