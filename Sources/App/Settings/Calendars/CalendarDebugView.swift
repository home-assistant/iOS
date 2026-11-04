import SFSafeSymbols
import Shared
import SwiftUI

/// Month view for a single Home Assistant calendar: the grid marks the days that have events and
/// the section below lists the selected day's events, fetched live from the server.
struct CalendarDebugView: View {
    @StateObject private var viewModel: CalendarDebugViewModel

    init(server: Server, calendar: HACalendar) {
        self._viewModel = StateObject(wrappedValue: CalendarDebugViewModel(server: server, calendar: calendar))
    }

    var body: some View {
        List {
            Section {
                // Laid out with plain stacks rather than a LazyVGrid: a lazy container nested in a
                // List row re-resolves its layout against an ambiguous viewport while the List
                // scrolls, which made the whole screen fight the scroll gesture.
                VStack(spacing: DesignSystem.Spaces.one) {
                    HStack {
                        Button {
                            viewModel.showPreviousMonth()
                        } label: {
                            Image(systemSymbol: .chevronLeft)
                                .contentShape(Rectangle())
                        }
                        Text(viewModel.monthTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        Button {
                            viewModel.showNextMonth()
                        } label: {
                            Image(systemSymbol: .chevronRight)
                                .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(hex: viewModel.calendar.backgroundColor))

                    HStack(spacing: .zero) {
                        ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                            Text(symbol)
                                .font(.caption2)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                                .frame(maxWidth: .infinity)
                        }
                    }

                    ForEach(Array(viewModel.visibleWeeks.enumerated()), id: \.offset) { _, week in
                        HStack(spacing: .zero) {
                            ForEach(week, id: \.self) { day in
                                Button {
                                    viewModel.selectedDate = day
                                } label: {
                                    VStack(spacing: DesignSystem.Spaces.micro) {
                                        Text(viewModel.dayNumber(day))
                                            .font(.callout)
                                            .foregroundStyle(dayForegroundStyle(for: day))
                                            .frame(
                                                width: DesignSystem.Spaces.four,
                                                height: DesignSystem.Spaces.four
                                            )
                                            .background {
                                                Circle()
                                                    .fill(Color(hex: viewModel.calendar.backgroundColor))
                                                    .opacity(viewModel.isSelected(day) ? 1 : 0)
                                            }
                                        Circle()
                                            .fill(Color(hex: viewModel.calendar.backgroundColor))
                                            .frame(
                                                width: DesignSystem.Spaces.half,
                                                height: DesignSystem.Spaces.half
                                            )
                                            .opacity(viewModel.hasEvents(on: day) ? 1 : 0)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spaces.one)
            }

            Section(viewModel.selectedDate.formatted(date: .complete, time: .omitted)) {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.selectedDayEvents.isEmpty {
                    Text(L10n.Settings.Debugging.Calendars.noEvents)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                ForEach(viewModel.selectedDayEvents) { event in
                    HStack(alignment: .top, spacing: DesignSystem.Spaces.oneAndHalf) {
                        RoundedRectangle(cornerRadius: DesignSystem.Spaces.micro)
                            .fill(Color(hex: viewModel.calendar.backgroundColor))
                            .frame(width: DesignSystem.Spaces.half)
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            Text(event.summary)
                            Text(timeRange(for: event))
                                .font(.footnote)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                            if let location = event.location, !location.isEmpty {
                                Label(location, systemSymbol: .mappinAndEllipse)
                                    .font(.footnote)
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                            }
                            if let description = event.description, !description.isEmpty {
                                Text(description)
                                    .font(.footnote)
                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(L10n.Settings.Debugging.Calendars.SupportedFeatures.title) {
                LabeledContent(L10n.Settings.Debugging.Calendars.entityId) {
                    Text(viewModel.calendar.entityId)
                }
                Label(
                    L10n.Settings.Debugging.Calendars.SupportedFeatures.create,
                    systemSymbol: viewModel.calendar.supports(.createEvent) ? .checkmarkCircleFill : .xmarkCircle
                )
                Label(
                    L10n.Settings.Debugging.Calendars.SupportedFeatures.update,
                    systemSymbol: viewModel.calendar.supports(.updateEvent) ? .checkmarkCircleFill : .xmarkCircle
                )
                Label(
                    L10n.Settings.Debugging.Calendars.SupportedFeatures.delete,
                    systemSymbol: viewModel.calendar.supports(.deleteEvent) ? .checkmarkCircleFill : .xmarkCircle
                )
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(viewModel.calendar.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadEvents()
        }
        .task(id: viewModel.visibleMonth) {
            await viewModel.loadEvents()
        }
    }

    private func timeRange(for event: HACalendarEvent) -> String {
        guard !event.isAllDay else { return L10n.Settings.Debugging.Calendars.allDay }
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private func dayForegroundStyle(for day: Date) -> Color {
        if viewModel.isSelected(day) {
            return .white
        }
        if viewModel.isToday(day) {
            return Color(hex: viewModel.calendar.backgroundColor)
        }
        return viewModel.isInVisibleMonth(day) ? Color(uiColor: .label) : Color(uiColor: .tertiaryLabel)
    }
}

#Preview {
    NavigationView {
        CalendarDebugView(
            server: ServerFixture.standard,
            calendar: HACalendar(
                id: "fake-calendar.family",
                serverId: "fake",
                entityId: "calendar.family",
                name: "Family",
                backgroundColor: HACalendar.defaultColor(at: 0),
                supportedFeatures: 7,
                sortOrder: 0
            )
        )
    }
}
