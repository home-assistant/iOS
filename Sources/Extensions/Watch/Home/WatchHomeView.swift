import SFSafeSymbols
import Shared
import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = WatchHomeViewModel()
    @State private var showAssist = false
    @State private var showSettings = false
    @State private var openFolderId: String?
    @State private var isEditing = false
    @State private var activeSheet: HomeSheet?

    /// Identifiable wrapper so a `MagicItem` can drive a `.sheet(item:)`.
    struct EditableItem: Identifiable {
        let id: String
        let item: MagicItem
    }

    /// A single sheet enum avoids stacking multiple `.sheet` modifiers on one view, which is
    /// unreliable on older watchOS.
    enum HomeSheet: Identifiable {
        case add
        case edit(EditableItem)

        var id: String {
            switch self {
            case .add: return "__add__"
            case let .edit(editable): return editable.id
            }
        }
    }

    // MARK: - Layout Constants

    private enum Constants {
        // Use DesignSystem spacing to derive standard button hit area
        // Assuming one equals 8pt, adjust by product rules
        static let headerButtonSize: CGFloat = DesignSystem.Spaces.five
        static let headerInterItemSpacing: CGFloat = DesignSystem.Spaces.half
        static let headerCenterSpacer: CGFloat = DesignSystem.Spaces.one
    }

    var body: some View {
        Group {
            if let folderId = openFolderId {
                ZStack(alignment: .topTrailing) {
                    WatchFolderContentView(folderId: folderId, viewModel: viewModel) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            openFolderId = nil
                        }
                    }
                    .transition(.move(edge: .trailing))

                    editHeaderButton
                        .padding(DesignSystem.Spaces.one)
                }
            } else {
                content
                    .transition(.move(edge: .leading))
            }
        }
        ._statusBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: AssistDefaultComplication.launchNotification)) { _ in
            showAssist = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchConfigDidChange)) { _ in
            viewModel.loadCache()
        }
        .fullScreenCover(isPresented: $showAssist, content: {
            if let serverId = viewModel.watchConfig.assist.serverId,
               let pipelineId = viewModel.watchConfig.assist.pipelineId {
                WatchAssistView.build(
                    serverId: serverId,
                    pipelineId: pipelineId
                )
            } else {
                fatalError("Assist launched without serverId or pipelineId")
            }
        })
        .sheet(isPresented: $showSettings) {
            WatchSettingsView()
        }
        .onChange(of: showSettings) { isPresented in
            if !isPresented {
                viewModel.loadCache()
            }
        }
        .alert(
            Text(verbatim: L10n.Watch.Config.Edit.title),
            isPresented: Binding(
                get: { viewModel.editErrorMessage != nil },
                set: { if !$0 { viewModel.editErrorMessage = nil } }
            )
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            if let editErrorMessage = viewModel.editErrorMessage {
                Text(verbatim: editErrorMessage)
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchNetworkInfo()
                viewModel.initialRoutine()
            }
        }
        .onChange(of: scenePhase) { newValue in
            switch newValue {
            case .active:
                Task {
                    await viewModel.fetchNetworkInfo()
                }
            case .background:
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        List {
            listHeader
            listContent
            if !isEditing {
                addRow
            }
            footer
        }
        .id(viewModel.configVersion)
        // Removing the safe area so our fake navigation bar buttons (header) can be place correctly
        .ignoresSafeArea([.all], edges: .top)
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .modify { view in
            if #available(watchOS 11.0, *) {
                view.toolbarVisibility(.hidden, for: .navigationBar)
            } else if #available(watchOS 9.0, *) {
                view.toolbar(.hidden, for: .navigationBar)
            } else {
                view.navigationBarHidden(true)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                WatchConfigAddView(viewModel: viewModel, folderId: nil)
            case let .edit(editable):
                NavigationView {
                    WatchConfigItemEditView(
                        mode: .edit,
                        placeholderName: viewModel.info(for: editable.item).name,
                        item: editable.item,
                        info: viewModel.info(for: editable.item)
                    ) { item in
                        viewModel.updateItem(item, info: viewModel.info(for: editable.item))
                        activeSheet = nil
                    } onDelete: {
                        viewModel.removeItem(editable.item)
                        viewModel.saveConfig()
                        activeSheet = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.watchConfig.items.isEmpty {
            Text(verbatim: L10n.Watch.Labels.noConfig)
                .font(.footnote)
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var listHeader: some View {
        HStack {
            if isEditing {
                doneButton
                Spacer()
            } else {
                // Leading: reload (+ pencil only when Assist exists)
                HStack(spacing: Constants.headerInterItemSpacing) {
                    navReloadButton
                        .frame(
                            width: Constants.headerButtonSize,
                            height: Constants.headerButtonSize,
                            alignment: .center
                        )
                    if viewModel.showAssist {
                        editHeaderButton
                            .frame(
                                width: Constants.headerButtonSize,
                                height: Constants.headerButtonSize,
                                alignment: .center
                            )
                    }
                }

                // Center: loading state stays centered
                Spacer(minLength: Constants.headerCenterSpacer)
                toolbarLoadingState
                Spacer(minLength: Constants.headerCenterSpacer)

                // Trailing: if Assist exists show assist, otherwise pencil takes the assist spot
                Group {
                    if viewModel.showAssist {
                        assistHeaderButton
                    } else {
                        editHeaderButton
                    }
                }
                .frame(width: Constants.headerButtonSize, height: Constants.headerButtonSize, alignment: .center)
            }
        }
        .listRowBackground(Color.clear)
        .padding(.top, DesignSystem.Spaces.one)
    }

    private var addRow: some View {
        Button {
            if viewModel.isPhoneReachable {
                activeSheet = .add
            } else {
                viewModel.editErrorMessage = L10n.Watch.Config.Edit.Error.notReachable
            }
        } label: {
            Label(L10n.Watch.Config.Add.title, systemSymbol: .plus)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .disabled(!viewModel.isPhoneReachable)
        .opacity(viewModel.isPhoneReachable ? 1 : 0.4)
        .watchItemRowStyle()
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

    private var editHeaderButton: some View {
        Button {
            enterEditMode()
        } label: {
            Image(systemSymbol: .pencil)
        }
        .buttonStyle(.plain)
        .circularGlassOrLegacyBackground(tint: .gray)
        .disabled(!viewModel.isPhoneReachable)
        .opacity(viewModel.isPhoneReachable ? 1 : 0.4)
    }

    @ViewBuilder
    private var inlineError: some View {
        if viewModel.showError {
            Text(viewModel.errorMessage)
                .font(.footnote)
                .listRowBackground(
                    Color.red.opacity(0.5)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.oneAndHalf))
                )
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ForEach(Array(viewModel.watchConfig.items.enumerated()), id: \.offset) { _, item in
            rowContent(for: item)
                .modify { view in
                    if isEditing {
                        view
                    } else {
                        view.onLongPressGesture { enterEditMode() }
                    }
                }
        }
        .onMove(perform: isEditing ? moveItems : nil)
        .onDelete(perform: isEditing ? deleteItems : nil)
    }

    @ViewBuilder
    private func rowContent(for item: MagicItem) -> some View {
        if isEditing {
            Button {
                activeSheet = .edit(.init(id: item.serverUniqueId, item: item))
            } label: {
                WatchConfigItemRow(
                    item: item,
                    itemInfo: viewModel.info(for: item),
                    trailingSymbol: .line3Horizontal
                )
            }
            .buttonStyle(.plain)
            .watchConfigRowBackground()
        } else if item.type == .folder {
            WatchFolderRow(item: item, itemInfo: viewModel.info(for: item)) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    openFolderId = item.id
                }
            }
        } else {
            WatchMagicViewRow(
                item: item,
                itemInfo: viewModel.info(for: item),
                subtitle: viewModel.serverName(for: item)
            )
        }
    }

    private func enterEditMode() {
        guard viewModel.isPhoneReachable else {
            viewModel.editErrorMessage = L10n.Watch.Config.Edit.Error.notReachable
            return
        }
        withAnimation { isEditing = true }
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        viewModel.moveItem(from: source, to: destination)
    }

    private func deleteItems(at offsets: IndexSet) {
        viewModel.deleteItem(at: offsets)
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
        Button(action: {
            showAssist = true
        }, label: {
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
                loadingState
                    .circularGlassOrLegacyBackground()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var loadingState: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }

    private var footer: some View {
        VStack(spacing: .zero) {
            appVersion
            ssidLabel
            settingsButton
        }
        .listRowBackground(Color.clear)
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemSymbol: .gearshapeFill)
        }
        .circularGlassOrLegacyBackground()
        .padding(DesignSystem.Spaces.one)
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

    @ViewBuilder
    private var ssidLabel: some View {
        if !viewModel.currentSSID.isEmpty {
            Label {
                Text(verbatim: viewModel.currentSSID)
                    .minimumScaleFactor(0.5)
            } icon: {
                Image(systemSymbol: .wifi)
            }
            .font(DesignSystem.Font.caption2)
            .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}
