#if !os(watchOS)
import SwiftUI

/// Browsable index of every component, grouped by category.
///
/// Frontend counterpart: the frontend's own `gallery/` package, published at
/// `design.home-assistant.io`. This is that gallery for the native components, and the pages there
/// are what each port was checked against.
public struct ComponentsLibraryView: View {
    public init() {}

    public var body: some View {
        List {
            ForEach(ComponentCategory.allCases) { category in
                NavigationLink {
                    List {
                        ForEach(DesignSystemComponent.allCases.filter { $0.category == category }) { component in
                            Section {
                                ComponentVariantsView(component: component)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, DesignSystem.Spaces.half)
                            } header: {
                                Text(component.title)
                            } footer: {
                                // The frontend element this was ported from and when it was last
                                // reconciled, so the gallery can be read beside
                                // `design.home-assistant.io` without going via the source. Absent
                                // for the app's own components, which have neither.
                                if let element = component.frontendComponentName {
                                    Text(
                                        component.frontendComponentVersion
                                            .map { "\(element) · \($0)" } ?? element
                                    )
                                    .font(.system(.caption, design: .monospaced))
                                }
                            }
                        }
                    }
                } label: {
                    Text(category.title)
                }
            }

            // Widgets are components too, but they only make sense at the sizes the system gives
            // them, so they get a screen that draws them at those sizes rather than a list row.
            Section {
                NavigationLink {
                    WidgetsGalleryView()
                } label: {
                    Text("Widgets")
                }
            }
        }
        .navigationTitle("Components")
    }
}

#Preview {
    NavigationStack {
        ComponentsLibraryView()
    }
}
#endif
