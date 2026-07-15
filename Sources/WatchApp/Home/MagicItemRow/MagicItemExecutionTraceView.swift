import SFSafeSymbols
import Shared
import SwiftUI

/// Full-screen live log shown while a magic item executes with the developer "Verbose item
/// execution" option on. Renders each trace entry as it arrives, auto-scrolling to the newest one,
/// so route decisions, states and errors are readable on-device.
struct MagicItemExecutionTraceView: View {
    @ObservedObject var trace: MagicItemExecutionTrace
    let itemName: String
    let onDone: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                header
                ForEach(trace.entries) { entry in
                    row(for: entry)
                        .id(entry.id)
                }
                // Always available: the user must be able to escape a hung execution.
                Button {
                    onDone()
                } label: {
                    Text(verbatim: L10n.doneLabel)
                        .frame(maxWidth: .infinity)
                }
                .id(doneButtonId)
            }
            .onChange(of: trace.entries.count) { _ in
                withAnimation {
                    proxy.scrollTo(doneButtonId, anchor: .bottom)
                }
            }
        }
    }

    private let doneButtonId = "done"

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            Text(verbatim: L10n.Watch.ItemExecutionTrace.title)
                .font(.headline)
            HStack(spacing: DesignSystem.Spaces.one) {
                if !trace.isFinished {
                    ProgressView()
                        .frame(width: 16, height: 16)
                    Text(verbatim: L10n.Watch.ItemExecutionTrace.running)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: itemName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowBackground(Color.clear)
    }

    private func row(for entry: MagicItemExecutionTrace.Entry) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
            Image(systemSymbol: symbol(for: entry.level))
                .font(.system(size: 12))
                .foregroundStyle(color(for: entry.level))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                Text(verbatim: entry.message)
                    .font(.system(size: 12))
                Text(verbatim: trace.elapsed(for: entry))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spaces.half)
    }

    private func symbol(for level: MagicItemExecutionTrace.Level) -> SFSymbol {
        switch level {
        case .info: return .circleFill
        case .success: return .checkmarkCircleFill
        case .error: return .exclamationmarkTriangleFill
        }
    }

    private func color(for level: MagicItemExecutionTrace.Level) -> Color {
        switch level {
        case .info: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}

#Preview {
    let trace = MagicItemExecutionTrace()
    trace.log(.info, "Running script.good_morning (script)")
    trace.log(.info, "iPhone reachability: immediatelyReachable")
    trace.log(.info, "Pinging Home Assistant directly…")
    trace.log(.error, "Ping failed after 2.31s")
    trace.log(.info, "Relaying via iPhone over Watch Connectivity…")
    trace.log(.success, "iPhone confirmed the action ran")
    trace.finish()
    return MagicItemExecutionTraceView(trace: trace, itemName: "Good Morning", onDone: {})
}
