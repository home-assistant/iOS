#if !os(watchOS)
import SwiftUI

public enum DesignSystemComponent: String, CaseIterable, Identifiable {
    case primaryButton
    case secondaryButton
    case outlinedButton
    case neutralButton
    case negativeButton
    case secondaryNegativeButton
    case criticalButton
    case linkButton
    case textButton
    case closeButton
    case sheetCloseButton
    case textField
    case card
    case bottomSheet
    case progressView
    case pill

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .primaryButton: "Primary Button"
        case .secondaryButton: "Secondary Button"
        case .outlinedButton: "Outlined Button"
        case .neutralButton: "Neutral Button"
        case .negativeButton: "Negative Button"
        case .secondaryNegativeButton: "Secondary Negative Button"
        case .criticalButton: "Critical Button"
        case .linkButton: "Link Button"
        case .textButton: "Text Button"
        case .closeButton: "Close Button"
        case .sheetCloseButton: "Sheet Close Button"
        case .textField: "Text Field"
        case .card: "Card"
        case .bottomSheet: "Bottom Sheet"
        case .progressView: "Progress View"
        case .pill: "Pill"
        }
    }

    public var category: ComponentCategory {
        switch self {
        case .primaryButton, .secondaryButton, .outlinedButton, .neutralButton, .negativeButton,
             .secondaryNegativeButton, .criticalButton, .linkButton, .textButton:
            .buttons
        case .closeButton, .sheetCloseButton:
            .controls
        case .textField:
            .inputs
        case .card, .bottomSheet:
            .containers
        case .progressView, .pill:
            .indicators
        }
    }

    @ViewBuilder public var preview: some View {
        switch self {
        case .primaryButton: Button("Primary") {}.buttonStyle(.primaryButton)
        case .secondaryButton: Button("Secondary") {}.buttonStyle(.secondaryButton)
        case .outlinedButton: Button("Outlined") {}.buttonStyle(.outlinedButton)
        case .neutralButton: Button("Neutral") {}.buttonStyle(.neutralButton)
        case .negativeButton: Button("Negative") {}.buttonStyle(.negativeButton)
        case .secondaryNegativeButton: Button("Secondary Negative") {}.buttonStyle(.secondaryNegativeButton)
        case .criticalButton: Button("Critical") {}.buttonStyle(.criticalButton)
        case .linkButton: Button("Link") {}.buttonStyle(.linkButton)
        case .textButton: Button("Text") {}.buttonStyle(.textButton)
        case .closeButton: CloseButton {}
        case .sheetCloseButton: SheetCloseButton {}
        case .textField: HATextField(placeholder: "Placeholder", text: .constant("Example"))
        case .card: CardView { Text("Card content").frame(maxWidth: .infinity, alignment: .leading) }
        case .bottomSheet: BottomSheetGalleryDemo()
        case .progressView: HAProgressView(style: .medium)
        case .pill:
            HStack(spacing: DesignSystem.Spaces.one) {
                PillView(text: "Selected", selected: true)
                PillView(text: "Normal", selected: false)
            }
        }
    }
}
#endif
