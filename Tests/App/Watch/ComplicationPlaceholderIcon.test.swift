@testable import Shared
import Testing

/// Runs in the app-hosted Tests-App target: rasterizing the placeholder glyph needs the Material
/// Design icon font, which the hostless Tests-Shared target (where the rest of the
/// `ComplicationRenderContext` tests live) cannot load.
struct ComplicationPlaceholderIconTests {
    @Test func visibleIconSlotWithoutIconRendersPlaceholder() {
        MaterialDesignIcons.register()
        var config = WatchComplicationConfig(
            serverId: "server",
            kind: .customTemplate,
            name: "Solar",
            customTextTemplate: "{{ tpl }}"
        )
        config.setSlotConfig(ComplicationSlotConfig(isVisible: true), slot: .icon, for: .circular)
        #expect(ComplicationRenderContext.icon(for: config, family: .circular) != nil)
    }
}
