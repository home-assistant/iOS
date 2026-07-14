import Shared
import SwiftUI

/// The horizontal strip of autocomplete chips shown above the keyboard while editing a Jinja
/// template (installed as the editor's input accessory view).
struct JinjaAutocompleteBar: View {
    let suggestions: [JinjaTemplateSuggestion]
    let onSelect: (JinjaTemplateSuggestion) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spaces.one) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        Text(verbatim: suggestion.label)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                            .padding(.vertical, DesignSystem.Spaces.half)
                            .background(
                                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.vertical, DesignSystem.Spaces.one)
        }
        .frame(height: 44)
    }
}

#Preview {
    JinjaAutocompleteBar(
        suggestions: JinjaAutocompleteProvider(entityIds: []).suggestions(text: "{{ ", cursorLocation: 3),
        onSelect: { _ in }
    )
    .background(Color(uiColor: .systemGroupedBackground))
}
