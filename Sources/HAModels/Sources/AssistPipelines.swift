import Foundation
import GRDB

/// An Assist pipeline as exposed by the server. The `HADataDecodable` conformance that maps the
/// websocket payload lives in an extension in the `Shared` module.
public struct Pipeline: Codable {
    public let conversationEngine: String?
    public let conversationLanguage: String?
    public let id: String
    public let language: String?
    public let name: String
    public let sttEngine: String?
    public let sttLanguage: String?
    public let ttsEngine: String?
    public let ttsLanguage: String?
    public let ttsVoice: String?
    public let wakeWordEntity: String?
    public let wakeWordId: String?

    public init(
        conversationEngine: String? = nil,
        conversationLanguage: String? = nil,
        id: String,
        language: String? = nil,
        name: String,
        sttEngine: String? = nil,
        sttLanguage: String? = nil,
        ttsEngine: String? = nil,
        ttsLanguage: String? = nil,
        ttsVoice: String? = nil,
        wakeWordEntity: String? = nil,
        wakeWordId: String? = nil
    ) {
        self.conversationEngine = conversationEngine
        self.conversationLanguage = conversationLanguage
        self.id = id
        self.language = language
        self.name = name
        self.sttEngine = sttEngine
        self.sttLanguage = sttLanguage
        self.ttsEngine = ttsEngine
        self.ttsLanguage = ttsLanguage
        self.ttsVoice = ttsVoice
        self.wakeWordEntity = wakeWordEntity
        self.wakeWordId = wakeWordId
    }
}

/// The Assist pipelines available for a server, saved in database. The initializer that maps the
/// `PipelineResponse` websocket payload and the `Current.database()`-backed queries live in
/// extensions in the `Shared` module.
public struct AssistPipelines: Codable, FetchableRecord, PersistableRecord {
    public let serverId: String
    public let preferredPipeline: String
    public let pipelines: [Pipeline]

    public init(serverId: String, preferredPipeline: String, pipelines: [Pipeline]) {
        self.serverId = serverId
        self.preferredPipeline = preferredPipeline
        self.pipelines = pipelines
    }
}
