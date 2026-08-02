import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

/// The screen every tap on a lock row opens — locks never toggle directly from the home screen.
///
/// A state-colored icon with the current state below it, a lock/unlock button pair, and — when
/// the lock advertises the open (unlatch) feature, mirroring the frontend's `more-info-lock` —
/// an open button. Buttons that can't act on the current state are disabled and greyed out.
struct WatchLockControlsView: View {
    @StateObject private var viewModel: WatchLockControlsViewModel

    /// The view model is built inside `StateObject`'s autoclosure, so creation (and its poller)
    /// is deferred until the screen is actually pushed.
    init(item: MagicItem, itemInfo: MagicItem.Info, initialEntity: HAEntity? = nil) {
        self._viewModel = .init(
            wrappedValue: WatchLockControlsViewModel(item: item, itemInfo: itemInfo, initialEntity: initialEntity)
        )
    }

    var body: some View {
        List {
            header
            if viewModel.isStale {
                staleWarning
            }
            Section {
                HStack(spacing: DesignSystem.Spaces.one) {
                    actionButton(symbol: .lockFill, label: L10n.Watch.LockControls.lock) {
                        viewModel.lock()
                    }
                    .disabled(!viewModel.canLock)
                    actionButton(symbol: .lockOpenFill, label: L10n.Watch.LockControls.unlock) {
                        viewModel.unlock()
                    }
                    .disabled(!viewModel.canUnlock)
                }
                .listRowBackground(Color.clear)
            }
            if viewModel.supportsOpen {
                Section {
                    actionButton(symbol: .doorLeftHandOpen, label: L10n.Watch.LockControls.open) {
                        viewModel.open()
                    }
                    .disabled(!viewModel.canOpen)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle(Text(verbatim: viewModel.name))
        .onAppear {
            viewModel.startStateUpdates()
        }
        .onDisappear {
            viewModel.stopStateUpdates()
        }
    }

    private var header: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.half) {
                Image(uiImage: viewModel.icon.image(
                    ofSize: .init(width: 24, height: 24),
                    color: viewModel.iconColor
                ))
                .watchRowIconContainer(color: viewModel.iconColor)
                if let stateText = viewModel.stateText {
                    Text(verbatim: stateText)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text(verbatim: L10n.Watch.EntityDetails.loading)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private var staleWarning: some View {
        Label {
            Text(verbatim: L10n.Watch.EntityDetails.stale)
                .font(.caption2)
        } icon: {
            Image(systemSymbol: .exclamationmarkCircleFill)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .orange)
        }
    }

    private func actionButton(symbol: SFSymbol, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spaces.half) {
                Image(systemSymbol: symbol)
                    .font(.body.weight(.semibold))
                Text(verbatim: label)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    MaterialDesignIcons.register()
    let item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
    let info = MagicItem.Info(
        id: "1-lock.front_door",
        name: "Front door",
        iconName: "mdi:lock"
    )
    let entity = try? HAEntity(
        entityId: "lock.front_door",
        state: "locked",
        lastChanged: Date(timeIntervalSinceNow: -600),
        lastUpdated: Date(timeIntervalSinceNow: -60),
        attributes: [
            "friendly_name": "Front door",
            "supported_features": 1,
        ],
        context: .init(id: "", userId: "", parentId: "")
    )
    // In the app this screen is pushed by a row inside the home's NavigationStack.
    return NavigationStack {
        WatchLockControlsView(item: item, itemInfo: info, initialEntity: entity)
    }
}
