import Foundation
@testable import HomeAssistant
import Testing

/// Locks down the wire shape of the `info` payload. Home Assistant decodes it into dataclasses
/// whose fields carry no defaults, so a renamed or dropped key does not fail here — it fails in the
/// integration's config flow with nothing pointing back at this app.
struct WyomingInfoTests {
    private func encodedInfo() throws -> [String: Any] {
        let attribution = WyomingInfo.Attribution(name: "Home Assistant Companion", url: "https://example.com")
        let info = WyomingInfo(
            asr: [WyomingInfo.AsrProgram(
                name: "apple-on-device-speech",
                description: "Speech-to-text",
                attribution: attribution,
                installed: true,
                version: "1.0",
                models: [WyomingInfo.AsrModel(
                    name: "apple-on-device-speech",
                    description: "Apple on-device speech recognition",
                    attribution: attribution,
                    installed: true,
                    version: "1.0",
                    languages: ["en-US"]
                )]
            )],
            tts: [WyomingInfo.TtsProgram(
                name: "apple-speech-synthesis",
                description: "Text-to-speech",
                attribution: attribution,
                installed: true,
                version: "1.0",
                voices: [WyomingInfo.TtsVoice(
                    name: "com.apple.voice.compact.en-US.Samantha",
                    description: "Samantha",
                    attribution: attribution,
                    installed: true,
                    version: "1.0",
                    languages: ["en-US"]
                )]
            )]
        )

        let data = try WyomingEventCodec.encoder.encode(info)
        let json = try JSONSerialization.jsonObject(with: data)
        return try #require(json as? [String: Any])
    }

    @Test func carriesEveryProgramList() throws {
        let info = try encodedInfo()

        for key in ["asr", "tts", "handle", "intent", "wake", "mic", "snd"] {
            #expect(info[key] is [Any], "info is missing the \(key) list")
        }
    }

    @Test func spellsOutEveryArtifactField() throws {
        let info = try encodedInfo()
        let asr = try #require((info["asr"] as? [[String: Any]])?.first)
        let model = try #require((asr["models"] as? [[String: Any]])?.first)

        for key in ["name", "attribution", "installed", "description", "version"] {
            #expect(asr[key] != nil, "the asr program is missing \(key)")
            #expect(model[key] != nil, "the asr model is missing \(key)")
        }
        #expect(model["languages"] as? [String] == ["en-US"])
        #expect(asr["supports_transcript_streaming"] as? Bool == false)
    }

    /// The voice id Home Assistant sends back in a `synthesize` is the `name`, so it has to be the
    /// stable identifier and not the display name, which repeats across languages.
    @Test func namesVoicesByIdentifier() throws {
        let info = try encodedInfo()
        let tts = try #require((info["tts"] as? [[String: Any]])?.first)
        let voice = try #require((tts["voices"] as? [[String: Any]])?.first)

        #expect(voice["name"] as? String == "com.apple.voice.compact.en-US.Samantha")
        #expect(voice["description"] as? String == "Samantha")
        #expect(voice["languages"] as? [String] == ["en-US"])
        #expect(tts["supports_synthesize_streaming"] as? Bool == false)
    }
}
