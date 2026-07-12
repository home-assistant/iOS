import Foundation
import GRDB
import HAKit

public struct PipelineResponse: HADataDecodable {
    public let preferredPipeline: String
    public let pipelines: [Pipeline]

    public init(data: HAData) throws {
        self.preferredPipeline = try data.decode("preferred_pipeline")
        self.pipelines = try data.decode("pipelines")
    }

    public init(preferredPipeline: String, pipelines: [Pipeline]) {
        self.preferredPipeline = preferredPipeline
        self.pipelines = pipelines
    }
}

// `Pipeline` itself lives in the `HAModels` package; this maps the websocket payload.
extension Pipeline: @retroactive HADataDecodable {
    public init(data: HAData) throws {
        self.init(
            conversationEngine: try? data.decode("conversation_engine"),
            conversationLanguage: try? data.decode("conversation_language"),
            id: try data.decode("id"),
            language: try? data.decode("language"),
            name: try data.decode("name"),
            sttEngine: try? data.decode("stt_engine"),
            sttLanguage: try? data.decode("stt_language"),
            ttsEngine: try? data.decode("tts_engine"),
            ttsLanguage: try? data.decode("tts_language"),
            ttsVoice: try? data.decode("tts_voice"),
            wakeWordEntity: try? data.decode("wake_word_entity"),
            wakeWordId: try? data.decode("wake_word_id")
        )
    }
}

public struct AssistResponse: HADataDecodable {
    public init(data: HAData) throws {
        self.data = try? data.decode("data")
        let type = try data.decode("type") as String
        if let eventType = AssistEvent(rawValue: type) {
            self.type = eventType
        } else {
            Current.Log.error("Unknown assist event type: \(type)")
            self.type = .unknown
        }
        self.timestamp = try data.decode("timestamp")
    }

    public struct AssistData: HADataDecodable {
        public let pipeline: String?
        public let language: String?
        public let intentOutput: IntentOutput?
        public let runnerData: RunnerData?
        public let sttOutput: SttOutput?
        public let ttsOutput: TtsOutput?
        public let code: String?
        public let message: String?
        public var chatLogDelta: ChatLogDelta?

        public init(data: HAData) throws {
            self.pipeline = try? data.decode("data")
            self.language = try? data.decode("language")
            self.intentOutput = try? data.decode("intent_output")
            self.chatLogDelta = try? data.decode("chat_log_delta")
            self.runnerData = try? data.decode("runner_data")
            self.sttOutput = try? data.decode("stt_output")
            self.ttsOutput = try? data.decode("tts_output")
            self.code = try? data.decode("code")
            self.message = try? data.decode("message")
        }

        public struct ChatLogDelta: HADataDecodable {
            public let content: String?
            public init(data: HAData) throws {
                self.content = try? data.decode("content")
            }
        }

        public struct SttOutput: HADataDecodable {
            public let text: String?
            public init(data: HAData) throws {
                self.text = try? data.decode("text")
            }
        }

        public struct TtsOutput: HADataDecodable {
            public let urlPath: String?
            public init(data: HAData) throws {
                // Even though API name it 'url' it is just the path without the base url
                self.urlPath = try? data.decode("url")
            }
        }

        public struct RunnerData: HADataDecodable {
            public init(data: HAData) throws {
                self.sttBinaryHandlerId = try? data.decode("stt_binary_handler_id")
                self.timeout = try? data.decode("timeout")
            }

            public let sttBinaryHandlerId: Int?
            public let timeout: Int?
        }

        public struct IntentOutput: HADataDecodable {
            public init(data: HAData) throws {
                self.response = try? data.decode("response")
                self.conversationId = try? data.decode("conversation_id")
                self.continueConversation = (try? data.decode("continue_conversation")) ?? false
            }

            public let response: Response?
            public let conversationId: String?
            public let continueConversation: Bool
        }

        public struct Response: HADataDecodable {
            public init(data: HAData) throws {
                self.speech = try data.decode("speech")
            }

            public let speech: Speech
        }

        public struct Speech: HADataDecodable {
            public init(data: HAData) throws {
                self.plain = try data.decode("plain")
            }

            public let plain: Plain
        }

        public struct Plain: HADataDecodable {
            public init(data: HAData) throws {
                self.speech = try data.decode("speech")
            }

            public let speech: String
        }
    }

    public let type: AssistEvent
    public let data: AssistData?
    public let timestamp: String
}

public enum AssistEvent: String, Codable {
    case runStart = "run-start"
    case runEnd = "run-end"
    case wakeWordStart = "wake_word-start"
    case wakeWordEnd = "wake_word-end"
    case sttStart = "stt-start"
    case sttVadStart = "stt-vad-start"
    case sttVadEnd = "stt-vad-end"
    case sttEnd = "stt-end"
    case intentStart = "intent-start"
    case intentEnd = "intent-end"
    case ttsStart = "tts-start"
    case ttsEnd = "tts-end"
    case intentProgress = "intent-progress"
    case error = "error"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = AssistEvent(rawValue: rawValue) ?? .unknown
    }
}

// `AssistPipelines` itself lives in the `HAModels` package; these map the websocket payload and
// provide its database-backed queries.
public extension AssistPipelines {
    init(serverId: String, pipelineResponse: PipelineResponse) {
        self.init(
            serverId: serverId,
            preferredPipeline: pipelineResponse.preferredPipeline,
            pipelines: pipelineResponse.pipelines
        )
    }

    static func config() throws -> [AssistPipelines]? {
        try Current.database().read({ db in
            try AssistPipelines.fetchAll(db)
        })
    }
}
