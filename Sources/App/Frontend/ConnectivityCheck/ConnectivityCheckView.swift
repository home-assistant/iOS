import SFSafeSymbols
import Shared
import SwiftUI

struct ConnectivityCheckView: View {
    @ObservedObject var state: ConnectivityCheckState
    let url: URL
    let onRunChecks: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            HStack {
                Text(L10n.Connectivity.Diagnostics.title)
                    .font(.headline.bold())
                Spacer()
                if !state.isRunning {
                    Button(action: onRunChecks) {
                        HStack(spacing: 4) {
                            Image(systemSymbol: .arrowClockwise)
                                .font(.caption)
                            Text(L10n.Connectivity.Diagnostics.runChecks)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }

            if state.checks.allSatisfy({ $0.result == .pending }) {
                Button(action: onRunChecks) {
                    Label(L10n.Connectivity.Diagnostics.start, systemSymbol: .stethoscope)
                }
                .buttonStyle(.primaryButton)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.oneAndHalf) {
                    ForEach(state.checks) { check in
                        ConnectivityCheckRow(check: check)
                    }
                }
            }
        }
        .padding(.vertical)
    }
}

struct ConnectivityCheckRow: View {
    let check: ConnectivityCheck

    var body: some View {
        HStack(spacing: DesignSystem.Spaces.one) {
            statusIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(check.type.localizedName)
                    .font(.body.bold())

                if case let .success(message) = check.result, let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if case let .failure(error) = check.result {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if check.result == .skipped {
                    Text(L10n.Connectivity.Check.skipped)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if check.result == .running {
                    Text(L10n.Connectivity.Check.running)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch check.result {
        case .pending:
            Image(systemSymbol: .circle)
                .foregroundStyle(.gray)
        case .running:
            ProgressView()
        case .success:
            Image(systemSymbol: .checkmarkCircleFill)
                .foregroundStyle(.green)
        case .failure:
            Image(systemSymbol: .xmarkCircleFill)
                .foregroundStyle(.red)
        case .skipped:
            Image(systemSymbol: .minusCircleFill)
                .foregroundStyle(.gray)
        }
    }
}

#Preview("Pending") {
    ConnectivityCheckView(
        state: ConnectivityCheckState(),
        url: URL(string: "https://example.com")!,
        onRunChecks: {}
    )
    .padding()
}

#Preview("Running") {
    let state = ConnectivityCheckState()
    state.updateCheck(type: .dns, result: .success(message: "Resolved to 93.184.216.34"))
    state.updateCheck(type: .port, result: .running)
    state.isRunning = true

    return ConnectivityCheckView(
        state: state,
        url: URL(string: "https://example.com")!,
        onRunChecks: {}
    )
    .padding()
}

#Preview("Success") {
    let state = ConnectivityCheckState()
    state.updateCheck(type: .dns, result: .success(message: "Resolved to 93.184.216.34"))
    state.updateCheck(type: .port, result: .success(message: "Port 443 is reachable"))
    state.updateCheck(type: .tls, result: .success(message: "Certificate is valid"))
    state.updateCheck(type: .server, result: .success(message: "Server responded with status 200"))

    return ConnectivityCheckView(
        state: state,
        url: URL(string: "https://example.com")!,
        onRunChecks: {}
    )
    .padding()
}

#Preview("Failure") {
    let state = ConnectivityCheckState()
    state.updateCheck(type: .dns, result: .success(message: "Resolved to 93.184.216.34"))
    state.updateCheck(type: .port, result: .failure(error: "Connection timeout"))
    state.updateCheck(type: .tls, result: .skipped)
    state.updateCheck(type: .server, result: .skipped)

    return ConnectivityCheckView(
        state: state,
        url: URL(string: "https://example.com")!,
        onRunChecks: {}
    )
    .padding()
}
