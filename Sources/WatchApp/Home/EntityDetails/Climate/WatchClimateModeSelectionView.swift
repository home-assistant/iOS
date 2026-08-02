import SFSafeSymbols
import Shared
import SwiftUI

/// Single-choice list the climate control screen navigates to for a mode attribute
/// (HVAC/fan/swing/preset): the current value carries a checkmark, and selecting an option
/// reports it back and pops.
struct WatchClimateModeSelectionView: View {
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
        WatchClimateModeSelectionView(
            title: "Mode",
            options: ["off", "heat", "cool", "heat_cool"],
            selected: "heat",
            displayName: { ClimateHvacMode.localizedTitle(forMode: $0) },
            onSelect: { _ in }
        )
    }
}
