import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDetailsAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Details"
    static let description = IntentDescription("Display states using from Home Assistant in text")
    
    @Parameter(title: "Server", default: nil)
    var server: IntentServerAppEntity
    
    @Parameter(title: "Upper Text Template", default: "", inputOptions: .init(capitalizationType: .none, multiline: true, autocorrect: false, smartQuotes: false, smartDashes: false))
    var upperTemplate: String
    
    @Parameter(title: "Lower Text Template", default: "", inputOptions: .init(capitalizationType: .none, multiline: true, autocorrect: false, smartQuotes: false, smartDashes: false))
    var lowerTemplate: String
    
    @Parameter(title: "Details Text Template (only in rectangular family)", default: "", inputOptions: .init(capitalizationType: .none, multiline: true, autocorrect: false, smartQuotes: false, smartDashes: false))
    var detailsTemplate: String
    
    @Parameter(title: "Run Action (only in rectangular family)", default: false)
    var runAction: Bool
    
    @Parameter(title: "Action", default: nil)
    var action: IntentActionAppEntity?
    
    static var parameterSummary: some ParameterSummary {
        When(\WidgetDetailsAppIntent.$runAction, .equalTo, true) {
            Summary() {
                \.$server
                \.$upperTemplate
                \.$lowerTemplate
                \.$detailsTemplate
                
                \.$runAction
                \.$action
            }
        } otherwise: {
            Summary() {
                \.$server
                \.$upperTemplate
                \.$lowerTemplate
                \.$detailsTemplate
                
                \.$runAction
            }
        }
    }
}
