#if !os(watchOS)
import SwiftUI

/// Every variant of one component, each under its name.
///
/// Shared by `ComponentsLibraryView` and the gallery snapshot test so the recorded images are
/// exactly what the in-app library shows.
///
/// Frontend counterpart: a demo page in the frontend's `gallery/` package. Gallery scaffolding, not
/// a component.
public struct ComponentVariantsView: View {
    private let component: DesignSystemComponent

    public init(component: DesignSystemComponent) {
        self.component = component
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
            ForEach(component.variants) { variant in
                VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
                    Text(variant.name)
                        .font(DesignSystem.Font.caption)
                        .foregroundStyle(.secondary)
                    variant.content
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScrollView {
        ComponentVariantsView(component: .alert)
            .padding()
    }
}
#endif
