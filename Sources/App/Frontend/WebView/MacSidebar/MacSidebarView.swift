import Shared
import SwiftUI
import UniformTypeIdentifiers

struct MacSidebarView: View {
    private enum Constants {
        static let hiddenRowOpacity: Double = 0.6
        static let draggingRowOpacity: Double = 0.4
        static let logoSize: CGFloat = 28
    }

    @ObservedObject var viewModel: MacSidebarViewModel
    @State private var draggingItemId: String?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spaces.micro) {
                if !viewModel.isEditing {
                    Image(.logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Constants.logoSize, height: Constants.logoSize)
                        .padding(.top, DesignSystem.Spaces.one)
                        .padding(.bottom, DesignSystem.Spaces.oneAndHalf)
                        .accessibilityHidden(true)
                } else {
                    HStack {
                        Text(L10n.Mac.Sidebar.edit)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L10n.Mac.Sidebar.done) {
                            viewModel.isEditing = false
                        }
                        .buttonStyle(.borderless)
                        .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, DesignSystem.Spaces.one)
                    .padding(.bottom, DesignSystem.Spaces.half)
                }
                ForEach(viewModel.mainItems) { item in
                    mainRow(for: item)
                }
                if viewModel.isEditing, !viewModel.hiddenItems.isEmpty {
                    Text(L10n.Mac.Sidebar.HiddenSection.header)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignSystem.Spaces.one)
                        .padding(.top, DesignSystem.Spaces.two)
                        .padding(.bottom, DesignSystem.Spaces.half)
                    ForEach(viewModel.hiddenItems) { item in
                        MacSidebarRow(
                            item: item,
                            isSelected: false,
                            server: viewModel.server,
                            user: viewModel.user,
                            accessory: .show,
                            onAccessoryTap: { viewModel.show(itemId: item.id) }
                        ) {}
                            .opacity(Constants.hiddenRowOpacity)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.one)
            .padding(.vertical, DesignSystem.Spaces.one)
            .onDrop(of: [.text], delegate: MacSidebarReorderDropDelegate(
                targetItemId: nil,
                draggingItemId: $draggingItemId,
                move: { _, _ in },
                commit: viewModel.commitReorder
            ))
        }
        .animation(DesignSystem.Animation.easeInOutFaster, value: viewModel.mainItems.map(\.id))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                VStack(spacing: DesignSystem.Spaces.micro) {
                    ForEach(viewModel.fixedItems) { item in
                        MacSidebarRow(
                            item: item,
                            isSelected: viewModel.selectedItemId == item.id,
                            server: viewModel.server,
                            user: viewModel.user,
                            isPinned: true
                        ) {
                            viewModel.select(itemId: item.id)
                        }
                    }
                }
                .padding(DesignSystem.Spaces.one)
            }
            .background(.bar)
        }
        .background(Color(uiColor: .secondarySystemBackground).ignoresSafeArea())
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    @ViewBuilder
    private func mainRow(for item: MacSidebarItem) -> some View {
        let row = MacSidebarRow(
            item: item,
            isSelected: !viewModel.isEditing && viewModel.selectedItemId == item.id,
            server: viewModel.server,
            user: viewModel.user,
            accessory: viewModel.isEditing && viewModel.canHide(item) ? .hide : nil,
            onAccessoryTap: { viewModel.hide(itemId: item.id) }
        ) {
            if !viewModel.isEditing {
                viewModel.select(itemId: item.id)
            }
        }
        .contextMenu {
            if viewModel.isEditing {
                Button(L10n.Mac.Sidebar.resetToDefaults) { viewModel.resetToDefaults() }
                Button(L10n.Mac.Sidebar.done) { viewModel.isEditing = false }
            } else {
                if viewModel.canHide(item) {
                    Button(L10n.Mac.Sidebar.hide) { viewModel.hide(itemId: item.id) }
                }
                Button(L10n.Mac.Sidebar.edit) { viewModel.isEditing = true }
            }
        }

        if viewModel.isEditing {
            row
                .opacity(draggingItemId == item.id ? Constants.draggingRowOpacity : 1)
                .onDrag {
                    draggingItemId = item.id
                    return NSItemProvider(object: item.id as NSString)
                }
                .onDrop(of: [.text], delegate: MacSidebarReorderDropDelegate(
                    targetItemId: item.id,
                    draggingItemId: $draggingItemId,
                    move: viewModel.moveItem,
                    commit: viewModel.commitReorder
                ))
        } else {
            row
        }
    }
}

#Preview {
    HStack(spacing: 0) {
        MacSidebarView(viewModel: .init(server: ServerFixture.standard, overlayState: .init()))
            .frame(width: 240)
        Divider()
        Text(verbatim: "Frontend")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
