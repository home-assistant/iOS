import SFSafeSymbols
import Shared
import SwiftUI

/// Entry point of the debug Calendars flow: picks whose server's calendars to inspect.
struct CalendarsDebugServerListView: View {
    @State private var calendarCounts: [String: Int] = [:]

    var body: some View {
        List {
            ForEach(Current.servers.all, id: \.identifier.rawValue) { server in
                NavigationLink {
                    CalendarsDebugListView(server: server)
                } label: {
                    HStack(spacing: DesignSystem.Spaces.two) {
                        Image(systemSymbol: .serverRack)
                            .foregroundStyle(Color.haPrimary)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(server.info.name)
                            Text(L10n.Settings.Debugging.Calendars.countD(
                                calendarCounts[server.identifier.rawValue] ?? 0
                            ))
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.Debugging.Calendars.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calendarCounts = Current.servers.all.reduce(into: [:]) { result, server in
                result[server.identifier.rawValue] = HACalendar.all(serverId: server.identifier.rawValue).count
            }
        }
    }
}

#Preview {
    NavigationView {
        CalendarsDebugServerListView()
    }
}
