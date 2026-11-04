import SFSafeSymbols
import Shared
import SwiftUI

/// The watch home screen's fake navigation header: reload + loading + Assist, or a Done button while
/// editing. Rendered as the first row of the home list.
struct WatchHomeHeaderView: View {
    @ObservedObject var viewModel: WatchHomeViewModel
    @Binding var isEditing: Bool
    @Binding var iPhoneNotReachable: Bool
    let onAssist: () -> Void
    let onAdd: () -> Void

    private enum Constants {
        static let headerButtonSize: CGFloat = 24
        static let headerCenterSpacer: CGFloat = DesignSystem.Spaces.one
        /// Keeps the sync progress bar + status text compact so they don't crowd the header buttons.
        static let loadingBarWidth: CGFloat = 70
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

                // Trailing: Assist, or the add button when Assist isn't configured
                trailingHeaderButton
                    .frame(width: Constants.headerButtonSize, height: Constants.headerButtonSize, alignment: .center)
            }
        }
        .listRowBackground(Color.clear)
        .padding(DesignSystem.Spaces.one)
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
            viewModel.requestConfig(userInitiated: true)
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
                VStack(spacing: DesignSystem.Spaces.half) {
                    Group {
                        if let progress = viewModel.syncProgress {
                            ProgressView(value: progress)
                        } else {
                            ProgressView()
                        }
                    }
                    .progressViewStyle(.linear)
                    .tint(.haPrimary)
                    .frame(width: Constants.loadingBarWidth)
                    if let status = viewModel.loadingStatus {
                        Text(verbatim: status)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.tail)
                            .frame(maxWidth: Constants.loadingBarWidth)
                    }
                }
            } else {
                HStack(spacing: DesignSystem.Spaces.one) {
                    Image(uiImage: Asset.logo.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: Constants.headerButtonSize, height: Constants.headerButtonSize)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    if iPhoneNotReachable {
                        Image(systemSymbol: .iphoneSlash)
                            .foregroundStyle(.secondary)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                            .offset(y: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var trailingHeaderButton: some View {
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
            addButton
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemSymbol: .plus)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground()
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

#if DEBUG
#Preview {
    WatchHomeHeaderView(
        viewModel: .init(),
        isEditing: .constant(false),
        iPhoneNotReachable: .constant(false),
        onAssist: {},
        onAdd: {}
    )
}

#Preview("iPhone not reachable") {
    WatchHomeHeaderView(
        viewModel: .init(),
        isEditing: .constant(false),
        iPhoneNotReachable: .constant(true),
        onAssist: {},
        onAdd: {}
    )
}
#endif
