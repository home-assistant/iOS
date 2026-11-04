#if !os(watchOS)
import HAIconic
import SwiftUI

/// One mode picker under a more-info dialog's main control: "Mode · Heat", "Fan mode · Low".
///
/// Frontend counterpart: the options and value a more-info control hands each
/// `ha-control-select-menu` it renders. A model rather than a view, so every dialog lays its
/// pickers out the same way through ``HAMoreInfoControlSelectContainer``.
public struct HAMoreInfoSelect: Identifiable {
    public let id: String
    public let label: String
    public let icon: MaterialDesignIcons
    public let options: [HAControlSelectOption]
    public let selection: Binding<String?>
    public let isDisabled: Bool

    /// - Parameters:
    ///   - icon: Shown when the selected option has no icon of its own.
    public init(
        id: String,
        label: String,
        icon: MaterialDesignIcons,
        options: [HAControlSelectOption],
        selection: Binding<String?>,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.label = label
        self.icon = icon
        self.options = options
        self.selection = selection
        self.isDisabled = isDisabled
    }
}
#endif
