import Shared
import SwiftUI

/// Picks which parts of the Home Assistant web interface kiosk mode hides on this device.
struct KioskFrontendElementsView: View {
    @Binding var hiddenElements: Set<KioskFrontendElement>

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .formatListChecksIcon,
                title: L10n.Kiosk.HiddenElements.title,
                subtitle: L10n.Kiosk.HiddenElements.body
            )

            Section {
                ForEach(KioskFrontendElement.allCases) { element in
                    Toggle(isOn: binding(for: element)) {
                        KioskRow.label(element.title, icon: element.icon)
                    }
                }
            } footer: {
                Text(L10n.Kiosk.HiddenElements.footer)
            }
        }
    }

    private func binding(for element: KioskFrontendElement) -> Binding<Bool> {
        Binding(
            get: { hiddenElements.contains(element) },
            set: { isHidden in
                if isHidden {
                    hiddenElements.insert(element)
                } else {
                    hiddenElements.remove(element)
                }
            }
        )
    }
}

#Preview {
    NavigationView {
        KioskFrontendElementsView(hiddenElements: .constant(KioskFrontendElement.defaultHidden))
    }
}
