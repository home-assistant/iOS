import SFSafeSymbols
import Shared
import SwiftUI

/// Single-choice list a control screen navigates to for a mode attribute (climate's
/// HVAC/fan/swing/preset modes, a vacuum's fan speed): the current value carries a checkmark, and
/// selecting an option reports it back and pops.
struct WatchModeSelectionView: View {
    let title: String
    let options: [String]
    let selected: String?
    let displayName: (String) -> String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                    dismiss()
                } label: {
                    HStack {
                        Text(verbatim: displayName(option))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if option == selected {
                            Image(systemSymbol: .checkmark)
                                .foregroundStyle(.haPrimary)
                        }
                    }
                }
            }
        }
        .navigationTitle(Text(verbatim: title))
    }
}

#Preview {
    NavigationView {
        WatchModeSelectionView(
            title: "Mode",
            options: ["off", "heat", "cool", "heat_cool"],
            selected: "heat",
            displayName: { ClimateHvacMode.localizedTitle(forMode: $0) },
            onSelect: { _ in }
        )
    }
}
