import HAKit
import Shared
import SwiftUI

/// Observable wrapper for the live template rendering subscription used by the
/// complication editor. Replaces the Eureka `TemplateSection` rendering logic.
final class TemplateRenderer: ObservableObject {
    enum Output: Equatable {
        case idle
        case loading
        case success(String)
        case failure(String)

        static func == (lhs: Output, rhs: Output) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading):
                return true
            case let (.success(a), .success(b)):
                return a == b
            case let (.failure(a), .failure(b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published private(set) var output: Output = .idle

    private let displayResult: (Any) throws -> String
    private var server: Server
    private var subscriptionToken: HACancellable?
    private var debounceTimer: Timer?
    private var template: String = ""

    init(server: Server, displayResult: @escaping (Any) throws -> String = { String(describing: $0) }) {
        self.server = server
        self.displayResult = displayResult
    }

    deinit {
        subscriptionToken?.cancel()
        debounceTimer?.invalidate()
    }

    func updateServer(_ server: Server) {
        self.server = server
        refresh(skipDelay: true)
    }

    func updateTemplate(_ template: String) {
        guard template != self.template else { return }
        self.template = template
        refresh()
    }

    /// Force a re-render without changing the template text. Useful when the
    /// view first appears and wants an immediate evaluation.
    func refreshNow() {
        refresh(skipDelay: true)
    }

    private func refresh(skipDelay: Bool = false) {
        subscriptionToken?.cancel()
        debounceTimer?.invalidate()

        let trimmed = template

        guard !trimmed.isEmpty else {
            output = .success("")
            return
        }

        guard trimmed.containsJinjaTemplate else {
            handle(success: trimmed)
            return
        }

        output = .loading

        let delay: TimeInterval = skipDelay ? 0 : (Current.isCatalyst ? 0.5 : 1.0)
        debounceTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.startSubscription()
        }
    }

    private func startSubscription() {
        guard let api = Current.api(for: server) else {
            // No API available for this server — surface that instead of leaving the
            // preview stuck on the loading spinner that `refresh()` set.
            handle(failure: HomeAssistantAPI.APIError.noAPIAvailable)
            return
        }
        subscriptionToken = api.connection.subscribe(
            to: .renderTemplate(template),
            initiated: { [weak self] result in
                if case let .failure(error) = result {
                    DispatchQueue.main.async {
                        self?.handle(failure: error)
                    }
                }
            },
            handler: { [weak self] _, result in
                DispatchQueue.main.async {
                    self?.handle(any: result.result)
                }
            }
        )
    }

    private func handle(any value: Any) {
        do {
            output = try .success(displayResult(value))
        } catch {
            output = .failure(error.localizedDescription)
        }
    }

    private func handle(success value: String) {
        output = .success(value)
    }

    private func handle(failure error: Error) {
        output = .failure(error.localizedDescription)
    }
}

/// A SwiftUI section that edits a Jinja template and renders a live preview.
/// Replaces the Eureka `TemplateSection`.
struct TemplatePreviewSection: View {
    let header: String?
    let footer: String?
    let title: String
    let placeholder: String
    @Binding var template: String
    @ObservedObject var renderer: TemplateRenderer

    var body: some View {
        Section {
            TextEditor(text: $template)
                .font(.system(.body, design: .monospaced))
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                .frame(minHeight: 100)
                .overlay(alignment: .topLeading) {
                    if template.isEmpty {
                        Text(placeholder)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(title)

            previewRow
        } header: {
            if let header { Text(header) }
        } footer: {
            if let footer { Text(footer) }
        }
        .onChange(of: template) { newValue in
            renderer.updateTemplate(newValue)
        }
        .onAppear {
            renderer.updateTemplate(template)
            renderer.refreshNow()
        }
    }

    @ViewBuilder
    private var previewRow: some View {
        switch renderer.output {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: DesignSystem.Spaces.one) {
                ProgressView()
                Text(L10n.Settings.ConnectionSection.Websocket.Status.connecting)
                    .foregroundColor(.secondary)
            }
        case let .success(value):
            Text(value)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .failure(message):
            Text(message)
                .foregroundColor(Color(.systemRed))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
