#if !os(watchOS)
import SwiftUI

public struct ComponentsLibraryView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                ForEach(ComponentCategory.allCases) { category in
                    NavigationLink {
                        List {
                            ForEach(DesignSystemComponent.allCases.filter { $0.category == category }) { component in
                                VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                                    Text(component.title)
                                        .font(DesignSystem.Font.subheadline)
                                        .foregroundStyle(.secondary)
                                    component.preview
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, DesignSystem.Spaces.half)
                            }
                        }
                    } label: {
                        Text(category.title)
                    }
                }
            }
            .navigationTitle("Components")
        }
    }
}

#Preview {
    NavigationStack {
        ComponentsLibraryView()
    }
}
#endif
