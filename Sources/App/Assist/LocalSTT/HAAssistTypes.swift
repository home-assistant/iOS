//
//  HAAssistTypes.swift
//
//  Type definitions and enums for transcription and recording
//

import Foundation
import AVFoundation

// MARK: - Transcription State
enum HAAssistTranscriptionState {
    case transcribing
    case notTranscribing
}

// MARK: - Transcription Error
enum HAAssistTranscriptionError: Error {
    case couldNotDownloadModel
    case failedToSetupRecognitionStream
    case invalidAudioDataType
    case localeNotSupported
    case noInternetForModelDownload
    case audioFilePathNotFound

    var descriptionString: String {
        switch self {
        case .couldNotDownloadModel:
            return "Could not download the model."
        case .failedToSetupRecognitionStream:
            return "Could not set up the speech recognition stream."
        case .invalidAudioDataType:
            return "Unsupported audio format."
        case .localeNotSupported:
            return "This locale is not yet supported by SpeechAnalyzer."
        case .noInternetForModelDownload:
            return "The model could not be downloaded because the user is not connected to internet."
        case .audioFilePathNotFound:
            return "Couldn't write audio to file."
        }
    }
}

// MARK: - Recording State
enum HAAssistRecordingState: Equatable {
    case stopped
    case recording
    case paused
}
