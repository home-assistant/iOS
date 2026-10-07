import CoreText
@testable import Shared
import Testing
import UIKit

/// The icon names are generated from `Tools/MaterialDesignIcons.json` while the glyphs come from the
/// font HAIconic bundles. Both are produced by `Tools/BuildMaterialDesignIconsFont.sh`, and when only
/// one of them is updated every icon added since the bundled font draws as a missing glyph.
struct MaterialDesignIconsFontTests {
    @Test func everyIconHasAGlyphInTheBundledFont() {
        MaterialDesignIcons.register()
        let font = UIFont(name: MaterialDesignIcons.familyName, size: 12)
        #expect(font != nil, "The Material Design icon font is not registered")
        guard let font else { return }

        let glyphs = CTFontCopyCharacterSet(font as CTFont) as CharacterSet
        let missing = MaterialDesignIcons.allCases.filter { icon in
            guard let scalar = icon.unicode.unicodeScalars.first else { return true }
            return !glyphs.contains(scalar)
        }

        #expect(
            missing.isEmpty,
            "\(missing.count) icons have no glyph, e.g. \(missing.prefix(5).map(\.name)). Run Tools/BuildMaterialDesignIconsFont.sh"
        )
    }
}
