import SwiftUI
import Shared

struct SelectionOption: Identifiable, Hashable {
    let id = UUID()
    let value: String
    let title: String
    let subtitle: String?
    let isRecommended: Bool
    
    init(value: String, title: String, subtitle: String? = nil, isRecommended: Bool = false) {
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.isRecommended = isRecommended
    }
}

struct SelectionOptionView<SelectionType: Hashable>: View {
    let options: [SelectionOption]
    let allowsMultipleSelection: Bool
    @Binding var singleSelection: SelectionType?
    @Binding var multipleSelection: Set<SelectionType>
    
    // Single selection initializer
    init(
        options: [SelectionOption],
        selection: Binding<SelectionType?>
    ) where SelectionType == String {
        self.options = options
        self.allowsMultipleSelection = false
        self._singleSelection = selection
        self._multipleSelection = .constant(Set<SelectionType>())
    }
    
    // Multiple selection initializer
    init(
        options: [SelectionOption],
        multipleSelection: Binding<Set<SelectionType>>
    ) where SelectionType == String {
        self.options = options
        self.allowsMultipleSelection = true
        self._singleSelection = .constant(nil)
        self._multipleSelection = multipleSelection
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            ForEach(options) { option in
                SelectionOptionRow(
                    option: option,
                    isSelected: isSelected(option),
                    allowsMultipleSelection: allowsMultipleSelection,
                    onTap: {
                        handleSelection(option)
                    }
                )
            }
        }
    }
    
    private func isSelected(_ option: SelectionOption) -> Bool {
        if let selectionType = option.value as? SelectionType, allowsMultipleSelection {
            return multipleSelection.contains(selectionType)
        } else {
            return singleSelection as? String == option.value
        }
    }
    
    private func handleSelection(_ option: SelectionOption) {
        if let selectionType = option.value as? SelectionType, allowsMultipleSelection {
            let value = selectionType
            if multipleSelection.contains(value) {
                multipleSelection.remove(value)
            } else {
                multipleSelection.insert(value)
            }
        } else {
            singleSelection = option.value as? SelectionType
        }
    }
}

private struct SelectionOptionRow: View {
    let option: SelectionOption
    let isSelected: Bool
    let allowsMultipleSelection: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.two) {
                // Radio button or checkbox
                SelectionIndicator(
                    isSelected: isSelected,
                    isMultipleSelection: allowsMultipleSelection
                )
                .padding(.top, DesignSystem.Spaces.half)

                VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                    Text(option.title)
                        .font(DesignSystem.Font.caption)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Font.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spaces.two)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected && option.isRecommended ? Color.haPrimary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                Color.gray.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SelectionIndicator: View {
    let isSelected: Bool
    let isMultipleSelection: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.haPrimary : Color.gray.opacity(0.5), lineWidth: 2)
                .frame(width: 20, height: 20)
            
            if isSelected {
                if isMultipleSelection {
                    // Checkmark for multiple selection
                    Image(systemSymbol: .checkmark)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.haPrimary)
                } else {
                    // Filled circle for single selection
                    Circle()
                        .fill(Color.haPrimary)
                        .frame(width: 10, height: 10)
                }
            }
        }
    }
}

#Preview("Single Selection") {
    @State var selection: String? = "secure"
    
    let options = [
        SelectionOption(
            value: "secure",
            title: "Most secure: Allow this app to know when you're home",
            subtitle: nil,
            isRecommended: true
        ),
        SelectionOption(
            value: "less_secure",
            title: "Less secure: Do not allow this app to know when you're home",
            subtitle: nil,
            isRecommended: false
        )
    ]
    
    return VStack {
        SelectionOptionView(options: options, selection: $selection)
        
        Text("Selected: \(selection ?? "None")")
            .padding()
    }
    .padding()
}

#Preview("Multiple Selection") {
    @State var selections: Set<String> = ["option1"]
    
    let options = [
        SelectionOption(
            value: "option1",
            title: "First Option",
            subtitle: "This is the first option with a subtitle",
            isRecommended: true
        ),
        SelectionOption(
            value: "option2",
            title: "Second Option",
            subtitle: "This is the second option",
            isRecommended: false
        ),
        SelectionOption(
            value: "option3",
            title: "Third Option",
            subtitle: nil,
            isRecommended: false
        )
    ]
    
    return VStack {
        SelectionOptionView(options: options, multipleSelection: $selections)
        
        Text("Selected: \(Array(selections).joined(separator: ", "))")
            .padding()
    }
    .padding()
}
