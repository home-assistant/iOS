import Foundation
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

public struct Pipeline: HADataDecodable {
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

    public init(data: HAData) throws {
        self.conversationEngine = try? data.decode("conversation_engine")
        self.conversationLanguage = try? data.decode("conversation_language")
        self.id = try data.decode("id")
        self.language = try? data.decode("language")
        self.name = try data.decode("name")
        self.sttEngine = try? data.decode("stt_engine")
        self.sttLanguage = try? data.decode("stt_language")
        self.ttsEngine = try? data.decode("tts_engine")
        self.ttsLanguage = try? data.decode("tts_language")
        self.ttsVoice = try? data.decode("tts_voice")
        self.wakeWordEntity = try? data.decode("wake_word_entity")
        self.wakeWordId = try? data.decode("wake_word_id")
    }

    /// Mainly for test purposes
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

public struct AssistResponse: HADataDecodable {
    public init(data: HAData) throws {
        self.data = try? data.decode("data")
        let type = try data.decode("type") as String
        self.type = AssistEvent(rawValue: type)!
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

        public init(data: HAData) throws {
            self.pipeline = try? data.decode("data")
            self.language = try? data.decode("language")
            self.intentOutput = try? data.decode("intent_output")
            self.runnerData = try? data.decode("runner_data")
            self.sttOutput = try? data.decode("stt_output")
            self.ttsOutput = try? data.decode("tts_output")
            self.code = try? data.decode("code")
            self.message = try? data.decode("message")
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
                // Even thought API name it 'url' it is just the path without the base url
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
            }

            public let response: Response?
            public let conversationId: String?
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
    case error = "error"
}
