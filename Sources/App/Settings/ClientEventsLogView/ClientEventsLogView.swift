import SFSafeSymbols
import Shared
import SwiftUI

struct ClientEventsLogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ClientEventsLogViewModel()
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            typeFilter
            eventsList
        }
        .searchable(text: $viewModel.searchTerm)
        .navigationTitle(L10n.Settings.EventLog.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showClearConfirmation = true
                } label: {
                    Text(L10n.ClientEvents.View.clear)
                }
                .confirmationDialog(
                    L10n.ClientEvents.View.ClearConfirm.title,
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(L10n.cancelLabel, role: .cancel) {
                        /* no-op */
                    }
                    Button(L10n.yesLabel, role: .destructive) {
                        Current.clientEventStore.clearAllEvents().cauterize()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.subscribeEvents()
        }
    }

    @ViewBuilder
    private var eventsList: some View {
        ForEach(filteredEvents, id: \.id) { event in
            listItem(event)
        }
        if filteredEvents.isEmpty {
            Text(L10n.ClientEvents.noEvents)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }

    private var filteredEvents: [ClientEvent] {
        viewModel.events.filter({ event in
            if viewModel.searchTerm.isEmpty, viewModel.typeFilter == nil {
                return true
            } else {
                if viewModel.searchTerm.isEmpty {
                    if let typeFilter = viewModel.typeFilter {
                        return event.type == typeFilter
                    } else {
                        return true
                    }
                } else {
                    let containsSearchTerm = event.text.lowercased().contains(viewModel.searchTerm.lowercased())
                    if let typeFilter = viewModel.typeFilter {
                        return event.type == typeFilter && containsSearchTerm
                    } else {
                        return containsSearchTerm
                    }
                }
            }
        })
    }

    private var typeFilter: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Group {
                        Button {
                            viewModel.resetTypeFilter()
                        } label: {
                            filterPill(L10n.ClientEvents.EventType.all, selected: viewModel.typeFilter == nil)
                        }
                        ForEach(ClientEvent.EventType.allCases.sorted { e1, e2 in
                            e1.displayText < e2.displayText
                        }, id: \.self) { type in
                            Button {
                                viewModel.typeFilter = type
                            } label: {
                                filterPill(type.displayText, selected: viewModel.typeFilter == type)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.easeIn(duration: 0.2), value: viewModel.typeFilter)
                }
            }
            .listRowBackground(Color.clear)
            .modify { view in
                if #available(iOS 17.0, *) {
                    view.scrollClipDisabled(true)
                } else {
                    view
                }
            }
        }
        .modify { view in
            if #available(iOS 17.0, *) {
                view.listSectionSpacing(Spaces.one)
            } else {
                view
            }
        }
    }

    private func filterPill(_ text: String, selected: Bool) -> some View {
        Text(text)
            .foregroundStyle(selected ? .white : Color(uiColor: .label))
            .padding(Spaces.one)
            .padding(.horizontal)
            .background(selected ? Color.asset(Asset.Colors.haPrimary) : Color.secondary.opacity(0.1))
            .clipShape(Capsule())
    }

    private func listItem(_ event: ClientEvent) -> some View {
        NavigationLink {
            eventDescription(event)
        } label: {
            VStack(spacing: Spaces.one) {
                HStack {
                    Group {
                        Group {
                            dateTimeLabel(event.date)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(event.type.displayText)
                            .frame(alignment: .trailing)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                Text(event.text)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func dateTimeLabel(_ date: Date) -> Text {
        Text(date, style: .date)
            +
            Text(" ")
            +
            Text(date, style: .time)
    }

    private func eventDescription(_ event: ClientEvent) -> some View {
        ScrollView {
            Text(event.jsonPayloadDescription ?? "--")
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .textSelection(.enabled)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .navigationTitle(dateTimeLabel(event.date))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ClientEventsLogView()
}
