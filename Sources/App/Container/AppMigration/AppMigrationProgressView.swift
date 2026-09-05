import SFSafeSymbols
import Shared
import SwiftUI

/// The step list shown while data is packaged or applied. Each row fills in as its step finishes, so
/// the user watches the migration happen rather than staring at one spinner.
///
/// A grouped `List` like the intro screen: the steps are ordinary rows in a section, and the transfer
/// bar is a section of its own that only exists while a payload is crossing in more than one link.
struct AppMigrationProgressView<Step: AppMigrationStepDescribing>: View where Step.AllCases == [Step] {
    let symbol: SFSymbol
    let title: String
    let subtitle: String
    let state: (Step) -> AppMigrationStepState
    /// Only set while a payload is crossing in more than one link; `nil` for the common single-link
    /// handoff, which has no round trips worth drawing a bar for.
    var transfer: AppMigrationTransferProgress?
    var transferCaption: String = ""

    var body: some View {
        List {
            AppMigrationHeaderRow(symbol: symbol, title: title, primaryDescription: subtitle)
                .appMigrationHeaderRowStyle()

            Section {
                ForEach(Step.allCases) { step in
                    AppMigrationStepRow(title: step.title, icon: step.icon, state: state(step))
                }
            }

            if let transfer {
                Section {
                    AppMigrationTransferProgressView(progress: transfer, caption: transferCaption)
                }
            }
        }
        .listTopContentMargin()
    }
}

#Preview {
    AppMigrationProgressView<AppMigrationExportStep>(
        symbol: .trayAndArrowUpFill,
        title: "Moving your data",
        subtitle: "This only takes a moment. Keep the app open.",
        state: { step in
            switch step {
            case .servers, .configuration, .packaging: return .done
            case .handoff: return .running
            }
        },
        transfer: .init(completed: 2, total: 5),
        transferCaption: "Part 3 of 5 — the two apps will swap a few times to move it all across."
    )
}
