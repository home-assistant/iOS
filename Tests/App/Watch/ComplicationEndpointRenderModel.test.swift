@testable import HomeAssistant
@testable import Shared
import Testing

struct ComplicationEndpointRenderModelTests {
    @available(iOS 17, *)
    @Test(arguments: [WatchComplicationConfig.Family.circular, .rectangular])
    func carriesIndependentEndpointLabelsToLockScreen(family: WatchComplicationConfig.Family) {
        let config = WatchComplicationConfig(
            serverId: "server",
            widgetFamily: family,
            kind: .customTemplate,
            families: [family.rawValue: .init(minLabelTemplate: "low", maxLabelTemplate: "high")]
        )
        let context = ComplicationRenderContext(
            config: config,
            value: "21.5°",
            fraction: 0.64,
            iconImage: nil,
            renderedTemplates: ["low": "12"]
        )
        #expect(context.circularRenderModel.minLabel == "12")
        #expect(context.circularRenderModel.maxLabel == nil)
        #expect(context.rectangularRenderModel.minLabel == "12")
        #expect(context.rectangularRenderModel.maxLabel == nil)
    }
}
