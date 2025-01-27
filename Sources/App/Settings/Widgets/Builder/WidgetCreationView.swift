import GRDB
import SFSafeSymbols
import Shared
import SwiftUI
import WidgetKit

struct WidgetCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WidgetCreationViewModel
    private let dismissAction: () -> Void
    init(widget: CustomWidget = CustomWidget(name: "", items: []), dismissAction: @escaping () -> Void) {
        self._viewModel = .init(wrappedValue: .init(widget: widget))
        self.dismissAction = dismissAction
    }

    var body: some View {
        List {
            widgetPreview
            nameField
            itemsView
        }
        .navigationTitle(L10n.Settings.Widgets.Create.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.save()
                } label: {
                    Text(L10n.saveLabel)
                }
            }
        }
        .onAppear {
            viewModel.load()
        }
        .onChange(of: viewModel.shouldDismiss) { newValue in
            if newValue {
                dismiss()
                dismissAction()
            }
        }
        .alert("", isPresented: $viewModel.showError, actions: {
            Button(action: {
                /* no-op */
            }, label: {
                Text(L10n.okLabel)
            })
        }, message: {
            Text(viewModel.errorMessage)
        })
        .sheet(isPresented: $viewModel.showAddItem) {
            MagicItemAddView(context: .widget) { magicItem in
                guard let magicItem else { return }
                viewModel.addItem(magicItem)
            }
        }
    }

    private var widgetPreview: some View {
        HStack {
            Spacer()
            VStack {
                if viewModel.widget.items.isEmpty {
                    Button(action: {
                        viewModel.showAddItem = true
                    }, label: {
                        Image(systemSymbol: .plus)
                            .font(.system(size: 30))
                    })
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                } else {
                    widgetPreviewItems
                }
            }
            .frame(width: widthForPreview(), height: heightForPreview())
            .background(Color.asset(Asset.Colors.primaryBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.1), radius: 2)
            .padding(.vertical)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }

    private var nameField: some View {
        Section(L10n.Settings.Widgets.Create.Name.title) {
            TextField(L10n.Settings.Widgets.Create.Name.placeholder, text: $viewModel.widget.name)
        }
    }

    private var itemsView: some View {
        Section {
            ForEach(viewModel.widget.items, id: \.serverUniqueId) { item in
                makeListItem(item: item)
            }
            .onMove { indices, newOffset in
                viewModel.moveItem(from: indices, to: newOffset)
            }
            .onDelete { indexSet in
                viewModel.deleteItem(at: indexSet)
            }
            Button {
                viewModel.showAddItem = true
            } label: {
                Label(L10n.Settings.Widgets.Create.AddItem.title, systemSymbol: .plus)
            }
        } header: {
            Text(L10n.Watch.Configuration.Items.title)
        } footer: {
            Text(L10n.Settings.Widgets.Create.Footer.title)
        }
    }

    private func makeListItem(item: MagicItem) -> some View {
        let itemInfo = viewModel.magicItemInfo(for: item) ?? .init(
            id: item.id,
            name: item.id,
            iconName: "",
            customization: nil
        )
        return makeListItemRow(item: item, info: itemInfo)
    }

    @ViewBuilder
    private func makeListItemRow(item: MagicItem, info: MagicItem.Info) -> some View {
        NavigationLink {
            MagicItemCustomizationView(mode: .edit, context: .widget, item: item) { updatedMagicItem in
                viewModel.updateItem(updatedMagicItem)
            }
        } label: {
            itemRow(item: item, info: info)
        }
    }

    private func itemRow(item: MagicItem, info: MagicItem.Info) -> some View {
        HStack {
            Image(uiImage: image(for: item, itemInfo: info, color: Asset.Colors.haPrimary.color))
            Text(item.name(info: info))
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: SFSymbol.line3Horizontal.rawValue)
                .foregroundStyle(.gray)
        }
    }

    private func image(
        for item: MagicItem,
        itemInfo: MagicItem.Info,
        color: UIColor? = nil
    ) -> UIImage {
        let icon: MaterialDesignIcons = item.icon(info: itemInfo)

        return icon.image(
            ofSize: .init(width: 18, height: 18),
            color: color ?? .init(hex: itemInfo.customization?.iconColor)
        )
    }

    private var widgetPreviewItems: some View {
        let models = viewModel.widget.items.map { magicItem in
            let info = viewModel.magicItemInfo(for: magicItem)
            let textColor = Color(hex: magicItem.customization?.textColor)
            let iconColor = Color(hex: magicItem.customization?.iconColor)
            let backgroundColor = Color(hex: magicItem.customization?.backgroundColor)
            let subtitle: String? = [.script, .scene, .button, .inputButton].contains(magicItem.domain) ? nil : L10n
                .Widgets.EntityState.placeholder

            let icon: MaterialDesignIcons = {
                if let info {
                    return magicItem.icon(info: info)
                } else {
                    return .gridIcon
                }
            }()

            let title: String = {
                if let info {
                    return magicItem.name(info: info)
                } else {
                    return magicItem.id
                }
            }()

            return WidgetBasicViewModel(
                id: magicItem.id,
                title: title,
                subtitle: subtitle,
                interactionType: .appIntent(.refresh),
                icon: icon,
                textColor: textColor,
                iconColor: iconColor,
                backgroundColor: backgroundColor,
                useCustomColors: magicItem.customization?.useCustomColors ?? false
            )
        }
        let modelsCount = models.count
        let columnCount = WidgetFamilySizes.columns(family: widgetFamilyPreview(), modelCount: modelsCount)
        let rows = Array(WidgetFamilySizes.rows(count: columnCount, models: models))
        return WidgetBasicView(
            type: .button,
            rows: rows,
            sizeStyle: WidgetFamilySizes.sizeStyle(
                family: widgetFamilyPreview(),
                modelsCount: modelsCount,
                rowsCount: rows.count
            )
        )
    }

    private func widgetFamilyPreview() -> WidgetFamily {
        if viewModel.widget.items.count <= 3 {
            return .systemSmall
        } else if viewModel.widget.items.count <= 6 {
            return .systemMedium
        } else {
            return .systemLarge
        }
    }

    private func heightForPreview() -> CGFloat {
        viewModel.widget.items.count <= 6 ? 160 : 310
    }

    private func widthForPreview() -> CGFloat {
        viewModel.widget.items.count <= 3 ? 160 : 350
    }
}

#Preview {
    NavigationView {
        VStack {}
            .sheet(isPresented: .constant(true)) {
                WidgetCreationView {}
            }
    }
}
