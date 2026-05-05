import AVFoundation
import Foundation

public enum CarPlayAssistAudioCategory: String, CaseIterable {
    case playAndRecord
    case playback
    case record

    public var avCategory: AVAudioSession.Category {
        switch self {
        case .playAndRecord:
            .playAndRecord
        case .playback:
            .playback
        case .record:
            .record
        }
    }

    public var title: String {
        switch self {
        case .playAndRecord:
            "playAndRecord"
        case .playback:
            "playback"
        case .record:
            "record"
        }
    }
}

public enum CarPlayAssistAudioMode: String, CaseIterable {
    case `default`
    case voiceChat
    case voicePrompt
    case spokenAudio
    case measurement

    public var avMode: AVAudioSession.Mode {
        switch self {
        case .default:
            .default
        case .voiceChat:
            .voiceChat
        case .voicePrompt:
            .voicePrompt
        case .spokenAudio:
            .spokenAudio
        case .measurement:
            .measurement
        }
    }

    public var title: String {
        rawValue
    }
}

public enum CarPlayAssistPreferredSampleRate: Int, CaseIterable {
    case rate16000 = 16000
    case rate24000 = 24000
    case rate44100 = 44100
    case rate48000 = 48000

    public var title: String {
        "\(rawValue) Hz"
    }

    public var value: Double {
        Double(rawValue)
    }
}

public enum CarPlayAssistTTSPlaybackStrategy: String, CaseIterable {
    case avPlayer
    case downloadedAVAudioPlayer

    public var title: String {
        switch self {
        case .avPlayer:
            "AVPlayer"
        case .downloadedAVAudioPlayer:
            "Download then AVAudioPlayer"
        }
    }
}

public enum CarPlayAssistPlaybackDelay: Int, CaseIterable {
    case none = 0
    case ms100 = 100
    case ms250 = 250
    case ms500 = 500
    case ms1000 = 1000

    public var title: String {
        switch self {
        case .none:
            "None"
        default:
            "\(rawValue) ms"
        }
    }

    public var seconds: Double {
        Double(rawValue) / 1000.0
    }
}

public struct CarPlayAssistDebugSettings {
    public var audioCategory: CarPlayAssistAudioCategory
    public var audioMode: CarPlayAssistAudioMode
    public var preferredSampleRate: CarPlayAssistPreferredSampleRate
    public var allowBluetoothHFP: Bool
    public var allowBluetoothA2DP: Bool
    public var duckOthers: Bool
    public var interruptSpokenAudio: Bool
    public var playRecordingIndicatorTone: Bool
    public var recorderManagesAudioSession: Bool
    public var ttsPlaybackStrategy: CarPlayAssistTTSPlaybackStrategy
    public var ttsReconfigureAudioSession: Bool
    public var ttsDeactivateBeforeReconfigure: Bool
    public var ttsActivateAudioSession: Bool
    public var ttsCategory: CarPlayAssistAudioCategory
    public var ttsMode: CarPlayAssistAudioMode
    public var ttsAllowBluetoothHFP: Bool
    public var ttsAllowBluetoothA2DP: Bool
    public var ttsDuckOthers: Bool
    public var ttsInterruptSpokenAudio: Bool
    public var avPlayerAutomaticallyWaitsToMinimizeStalling: Bool
    public var ttsPlaybackDelay: CarPlayAssistPlaybackDelay

    public static let `default` = CarPlayAssistDebugSettings(
        audioCategory: .playAndRecord,
        audioMode: .voiceChat,
        preferredSampleRate: .rate16000,
        allowBluetoothHFP: true,
        allowBluetoothA2DP: true,
        duckOthers: false,
        interruptSpokenAudio: false,
        playRecordingIndicatorTone: true,
        recorderManagesAudioSession: false,
        ttsPlaybackStrategy: .avPlayer,
        ttsReconfigureAudioSession: false,
        ttsDeactivateBeforeReconfigure: false,
        ttsActivateAudioSession: true,
        ttsCategory: .playAndRecord,
        ttsMode: .voicePrompt,
        ttsAllowBluetoothHFP: true,
        ttsAllowBluetoothA2DP: true,
        ttsDuckOthers: false,
        ttsInterruptSpokenAudio: true,
        avPlayerAutomaticallyWaitsToMinimizeStalling: true,
        ttsPlaybackDelay: .none
    )
}
