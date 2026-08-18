import SFSafeSymbols
import Shared
import SwiftUI

/// Calendars stored for a server. Pull to refresh re-reads them from Home Assistant.
struct CalendarsDebugListView: View {
    private let server: Server
    @StateObject private var viewModel: CalendarsDebugListViewModel

    init(server: Server) {
        self.server = server
        self._viewModel = StateObject(wrappedValue: CalendarsDebugListViewModel(server: server))
    }

    var body: some View {
        List {
            if viewModel.calendars.isEmpty {
                VStack(spacing: DesignSystem.Spaces.one) {
                    Image(systemSymbol: .calendar)
                        .font(.largeTitle)
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    Text(L10n.Settings.Debugging.Calendars.Empty.title)
                        .font(.headline)
                    Text(L10n.Settings.Debugging.Calendars.Empty.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spaces.four)
                .listRowBackground(Color.clear)
            }
            ForEach(viewModel.calendars) { calendar in
                NavigationLink {
                    CalendarDebugView(server: server, calendar: calendar)
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Circle()
                            .fill(Color(hex: calendar.backgroundColor))
                            .frame(width: DesignSystem.Spaces.one + DesignSystem.Spaces.half)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(calendar.name)
                            Text(calendar.entityId)
                                .font(.footnote)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                    }
                }
            }
        }
        .navigationTitle(server.info.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            viewModel.load()
        }
        .alert(
            L10n.errorLabel,
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { newValue in
                    if !newValue { viewModel.errorMessage = nil }
                }
            )
        ) {
            Button(role: .cancel, action: { /* no-op */ }) {
                Text(verbatim: L10n.okLabel)
            }
        } message: {
            Text(viewModel.errorMessage.orEmpty)
        }
    }
}

#Preview {
    NavigationView {
        CalendarsDebugListView(server: ServerFixture.standard)
    }
}
