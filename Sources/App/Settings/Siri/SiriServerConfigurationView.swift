import SFSafeSymbols
import Shared
import SwiftUI

struct SiriServerConfigurationView: View {
    @StateObject private var viewModel: SiriServerConfigurationViewModel

    init(server: Server) {
        _viewModel = StateObject(wrappedValue: SiriServerConfigurationViewModel(server: server))
    }

    init(viewModel: SiriServerConfigurationViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            exposureSection(
                header: L10n.Settings.Siri.Configure.Calendars.header,
                footer: L10n.Settings.Siri.Configure.Calendars.footer,
                empty: L10n.Settings.Siri.Configure.Calendars.empty,
                items: viewModel.calendars,
                defaultId: viewModel.defaultCalendarId,
                domain: .calendar
            )
            exposureSection(
                header: L10n.Settings.Siri.Configure.Lists.header,
                footer: L10n.Settings.Siri.Configure.Lists.footer,
                empty: L10n.Settings.Siri.Configure.Lists.empty,
                items: viewModel.lists,
                defaultId: viewModel.defaultListId,
                domain: .todo
            )
        }
        .navigationTitle(viewModel.serverName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isReloading {
                    ProgressView()
                } else {
                    Button(action: viewModel.reload) {
                        Image(systemSymbol: .arrowClockwise)
                    }
                    .accessibilityLabel(L10n.Settings.Siri.Configure.reload)
                }
            }
        }
        .refreshable { viewModel.reload() }
        .onAppear { viewModel.load() }
    }

    @ViewBuilder
    private func exposureSection(
        header: String,
        footer: String,
        empty: String,
        items: [SiriServerConfigurationViewModel.Item],
        defaultId: String?,
        domain: Domain
    ) -> some View {
        Section(header: Text(header), footer: Text(footer)) {
            if items.isEmpty {
                Text(empty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    Toggle(isOn: Binding(
                        get: { item.isExposed },
                        set: { viewModel.setExposed($0, item: item, domain: domain) }
                    )) {
                        Text(item.name)
                    }
                }
                Picker(
                    L10n.Settings.Siri.Configure.defaultTitle,
                    selection: Binding(
                        get: { defaultId },
                        set: { viewModel.setDefault($0, domain: domain) }
                    )
                ) {
                    Text(L10n.Settings.Siri.Configure.defaultNone).tag(String?.none)
                    ForEach(items.filter(\.isExposed)) { item in
                        Text(item.name).tag(String?.some(item.id))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

#Preview {
    NavigationView {
        SiriServerConfigurationView(server: ServerFixture.standard)
    }
}
