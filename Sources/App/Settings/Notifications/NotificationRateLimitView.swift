import PromiseKit
import Shared
import SwiftUI

struct NotificationRateLimitView: View {
    @StateObject private var viewModel: NotificationRateLimitViewModel
    var onChange: (RateLimitResponse) -> Void

    init(
        initialPromise: Promise<RateLimitResponse>? = nil,
        onChange: @escaping (RateLimitResponse) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: NotificationRateLimitViewModel(initialPromise: initialPromise))
        self.onChange = onChange
    }

    var body: some View {
        List {
            content
        }
        .navigationTitle(L10n.SettingsDetails.Notifications.RateLimits.header)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ConditionalRefreshableModifier(enabled: !Current.isCatalyst) {
            await viewModel.refresh()
        })
        .toolbar {
            // `if` directly inside `.toolbar` requires iOS 16+ ToolbarContentBuilder.
            // Move the conditional inside the item so it works on iOS 15 too.
            ToolbarItem(placement: .primaryAction) {
                if Current.isCatalyst {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemSymbol: .arrowClockwise)
                    }
                    .disabled(viewModel.isRefreshing)
                }
            }
        }
        .onAppear {
            viewModel.onChange = onChange
            Task { await viewModel.refreshIfNeeded() }
            viewModel.startTimer()
        }
        .onDisappear {
            viewModel.stopTimer()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        case let .loaded(response):
            Section {
                row(
                    title: L10n.SettingsDetails.Notifications.RateLimits.attempts,
                    value: format(response.rateLimits.attempts)
                )
                row(
                    title: L10n.SettingsDetails.Notifications.RateLimits.delivered,
                    value: format(response.rateLimits.successful)
                )
                row(
                    title: L10n.SettingsDetails.Notifications.RateLimits.errors,
                    value: format(response.rateLimits.errors)
                )
                row(
                    title: L10n.SettingsDetails.Notifications.RateLimits.total,
                    value: format(response.rateLimits.total)
                )
                row(
                    title: L10n.SettingsDetails.Notifications.RateLimits.resetsIn,
                    value: viewModel.resetsInText ?? resetsAtAbsolute(response.rateLimits.resetsAt)
                )
            } footer: {
                Text(L10n.SettingsDetails.Notifications.RateLimits.footerWithParam(response.rateLimits.maximum))
            }
        case let .error(message):
            Section {
                Text(message)
                    .foregroundColor(.secondary)
                Button(L10n.retryLabel) {
                    Task { await viewModel.refresh() }
                }
            }
        }
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func format(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .none)
    }

    private func resetsAtAbsolute(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }
}

// MARK: - View Model

@MainActor
final class NotificationRateLimitViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(RateLimitResponse)
        case error(String)
    }

    enum RateLimitError: Error {
        case noPushId
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var resetsInText: String?
    @Published private(set) var isRefreshing = false

    var onChange: (RateLimitResponse) -> Void = { _ in }

    private var initialPromise: Promise<RateLimitResponse>?
    private var timer: Timer?
    private let utc = TimeZone(identifier: "UTC") ?? .current

    init(initialPromise: Promise<RateLimitResponse>?) {
        self.initialPromise = initialPromise
    }

    static func newPromise() -> Promise<RateLimitResponse> {
        if let pushID = Current.settingsStore.pushID {
            return NotificationRateLimitsAPI.rateLimits(pushID: pushID)
        } else {
            return .init(error: RateLimitError.noPushId)
        }
    }

    func refreshIfNeeded() async {
        if case .loading = state {
            await refresh()
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let response: RateLimitResponse
            if let initialPromise {
                self.initialPromise = nil
                response = try await initialPromise.asyncValue
            } else {
                response = try await Self.newPromise().asyncValue
            }
            state = .loaded(response)
            onChange(response)
            updateResetsIn()
        } catch {
            Current.Log.error("couldn't load rate limit: \(error)")
            state = .error(error.localizedDescription)
        }
    }

    func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateResetsIn()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateResetsIn() {
        var calendar = Calendar.current
        calendar.timeZone = utc

        guard let startOfNextDay = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) else {
            resetsInText = nil
            return
        }

        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.hour, .minute, .second]

        resetsInText = formatter.string(from: Date(), to: startOfNextDay)
    }
}

// MARK: - Promise async helper

private extension Promise {
    var asyncValue: T {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                self.done { value in
                    continuation.resume(returning: value)
                }.catch { error in
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Conditional refreshable modifier

private struct ConditionalRefreshableModifier: ViewModifier {
    let enabled: Bool
    let action: () async -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.refreshable { await action() }
        } else {
            content
        }
    }
}
