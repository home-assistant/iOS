import Intents
@testable import Shared
import Testing
import UIKit

/// Siri images drawn from Material Design icons; needs the icon font bundle the app ships.
struct INImageMaterialDesignIconsTests {
    @Test func iconsRenderIntoDistinctImages() {
        let light = INImage(icon: .lightbulbIcon, foreground: .white, background: .blue)
        let fan = INImage(icon: .fanIcon, foreground: .black, background: .white)
        #expect(light != fan)
    }
}
