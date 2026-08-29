#if !os(watchOS)
import SwiftUI

/// One card in an ``HASelectBox``, mirroring the frontend's `SelectBoxOption`.
///
/// The frontend takes an image URL; the package draws no network images, so the caller hands in an
/// already-resolved `Image` — the same arrangement the design system uses for the app's logo.
public struct HASelectBoxOption: Identifiable {
    public let id: String
    public let label: String
    public let description: String?
    public let image: Image?
    public let isDisabled: Bool

    public init(
        id: String,
        label: String,
        description: String? = nil,
        image: Image? = nil,
        isDisabled: Bool = false
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.image = image
        self.isDisabled = isDisabled
    }
}

extension HASelectBoxOption: FrontendComponent {
    public static var frontendComponentName: String { "ha-select-box" }
}

#endif
