import Foundation

/// The `info` payload this server answers a `describe` with.
///
/// The nested types mirror the Wyoming schema one for one — an artifact's five keys plus whatever
/// the program adds — so they are declared here rather than in files of their own: splitting them
/// would scatter a single wire format across six places, and none of them is used anywhere else.
struct WyomingInfo: Encodable {
    struct Attribution: Encodable {
        let name: String
        let url: String
    }

    struct AsrModel: Encodable {
        let name: String
        let description: String
        let attribution: Attribution
        let installed: Bool
        let version: String
        /// BCP 47 tags, e.g. `en-US`. Home Assistant offers exactly these as the pipeline's
        /// speech-to-text languages.
        let languages: [String]
    }

    struct AsrProgram: Encodable {
        let name: String
        let description: String
        let attribution: Attribution
        let installed: Bool
        let version: String
        let models: [AsrModel]
        /// This server answers with a single `transcript` once the audio ends, never with the
        /// `transcript-start`/`transcript-chunk` stream.
        let supportsTranscriptStreaming = false
    }

    struct TtsVoice: Encodable {
        /// The voice id Home Assistant sends back in a `synthesize`. It is the
        /// `AVSpeechSynthesisVoice` identifier, which is stable across launches, rather than the
        /// display name, which is not unique.
        let name: String
        let description: String
        let attribution: Attribution
        let installed: Bool
        let version: String
        let languages: [String]
    }

    struct TtsProgram: Encodable {
        let name: String
        let description: String
        let attribution: Attribution
        let installed: Bool
        let version: String
        let voices: [TtsVoice]
        /// Speech is rendered in one pass and sent as a finished `audio-start`/`audio-stop` run.
        let supportsSynthesizeStreaming = false
    }

    let asr: [AsrProgram]
    let tts: [TtsProgram]
    let handle: [String]
    let intent: [String]
    let wake: [String]
    let mic: [String]
    let snd: [String]

    init(asr: [AsrProgram], tts: [TtsProgram]) {
        self.asr = asr
        self.tts = tts
        // Wyoming's own writer emits every program list, and clients are free to read them without
        // a default, so the categories this server does not implement go out as empty arrays.
        self.handle = []
        self.intent = []
        self.wake = []
        self.mic = []
        self.snd = []
    }
}
