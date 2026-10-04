import Foundation

/// Sends one Assist recording to the iPhone while it is being made, the way in-app Assist streams
/// the microphone: the iPhone hears the audio as the user speaks, and says when they stopped.
///
/// One message is in flight at a time, and everything recorded while waiting for the iPhone's
/// acknowledgement goes out in the next chunk: the stream keeps pace with the link instead of
/// queueing a message per audio buffer, and arrives in order.
///
/// The whole recording is kept until the iPhone acknowledges the start. An iPhone that predates
/// streaming never answers it, so when no answer comes in time — or the iPhone is known to be too
/// old — the recording is uploaded whole once the user submits it, as it always was.
///
/// Compiled on every platform (not just watchOS), as `WatchRequestRelay` is, so it stays testable
/// from the iOS unit-test target. Used from the main queue only, which is where `send` calls back.
public final class WatchAssistAudioStream {
    /// Sends `message`, calling its reply — or `errorHandler`, once `timeout` passes without one —
    /// on the main queue.
    public typealias Send = (
        _ message: HAWatchConnectivity.InteractiveImmediateMessage,
        _ timeout: TimeInterval,
        _ errorHandler: @escaping (Error) -> Void
    ) -> Void

    /// What submitting the recording leaves to do.
    public enum Submission: Equatable {
        /// Nothing: the iPhone has the recording, or the rest of it is on its way.
        case sent
        /// The recording was not streamed, so it is uploaded whole.
        case upload(Data)
    }

    private enum Constants {
        /// An iPhone that streams answers the start straight away; one that predates streaming never
        /// does, and waiting longer would only hold up the stream.
        static let startTimeout: TimeInterval = 5
        static let chunkTimeout: TimeInterval = 10
        /// Audio waits until there is at least this much of it, so a fast link does not get a
        /// message per audio buffer.
        static let minimumChunkDuration: TimeInterval = 0.2
        /// A second of 16 kHz audio, well under the ~65 KB message ceiling.
        static let maximumChunkSize = 32 * 1024
        /// The audio is 16-bit mono PCM.
        static let bytesPerFrame = 2
    }

    private enum Mode {
        /// The start is on its way: the whole recording is kept until the iPhone acknowledges it.
        case starting
        case streaming
        /// Kept whole, to upload once submitted.
        case buffering
        /// The iPhone stopped listening, or the stream was submitted, cancelled or failed.
        case ended
    }

    public let id: String
    /// Of the 16-bit mono PCM appended to the stream.
    public let sampleRate: Double

    /// The iPhone stopped listening — it heard the user stop speaking, or the run is over — so the
    /// recording stops without the user submitting it.
    public var onStopRecording: (() -> Void)?
    /// The stream broke: the iPhone did not acknowledge a chunk.
    public var onFailure: ((Error) -> Void)?

    private let pipelineId: String
    private let serverId: String
    private let phoneSupportsStreaming: Bool
    private let send: Send
    private let minimumChunkSize: Int

    private var mode: Mode = .starting
    /// The whole recording while starting or buffering; what has not been sent yet while streaming.
    private var pendingAudio = Data()
    private var nextSequence = 0
    private var isAwaitingAcknowledgement = false
    private var isSubmitted = false

    /// - Parameter phoneSupportsStreaming: `false` when the iPhone is known to predate streaming,
    ///   which skips straight to uploading the recording once it ends.
    public init(
        id: String = UUID().uuidString,
        sampleRate: Double,
        pipelineId: String,
        serverId: String,
        phoneSupportsStreaming: Bool,
        send: @escaping Send
    ) {
        self.id = id
        self.sampleRate = sampleRate
        self.pipelineId = pipelineId
        self.serverId = serverId
        self.phoneSupportsStreaming = phoneSupportsStreaming
        self.send = send
        self.minimumChunkSize = Int(sampleRate * Constants.minimumChunkDuration) * Constants.bytesPerFrame
    }

    public func start() {
        guard phoneSupportsStreaming else {
            mode = .buffering
            return
        }
        isAwaitingAcknowledgement = true
        send(
            .init(
                identifier: InteractiveImmediateMessages.assistAudioStreamStart.rawValue,
                content: AssistAudioStreamStartPayload(
                    streamId: id,
                    sampleRate: sampleRate,
                    pipelineId: pipelineId,
                    serverId: serverId
                ).content,
                reply: { [weak self] reply in
                    self?.didAcknowledgeStart(reply)
                }
            ),
            Constants.startTimeout,
            { [weak self] error in
                self?.didFailToStart(error)
            }
        )
    }

    public func append(_ audio: Data) {
        guard mode != .ended, !isSubmitted else { return }
        pendingAudio.append(audio)
        sendNextChunkIfNeeded()
    }

    /// The user submitted the recording, or it stopped because the iPhone stopped listening.
    public func submit() -> Submission {
        guard !isSubmitted else { return .sent }
        isSubmitted = true
        switch mode {
        case .starting, .buffering:
            mode = .ended
            let recording = pendingAudio
            pendingAudio = Data()
            return .upload(recording)
        case .streaming:
            sendNextChunkIfNeeded()
            return .sent
        case .ended:
            return .sent
        }
    }

    /// Drops the recording: the user was not asking anything, so the iPhone abandons its run.
    public func cancel() {
        let phoneIsListening = [.starting, .streaming].contains(mode) && !isSubmitted
        mode = .ended
        pendingAudio = Data()
        guard phoneIsListening else { return }
        send(
            .init(
                identifier: InteractiveImmediateMessages.assistAudioStreamCancel.rawValue,
                content: AssistAudioStreamEndPayload(streamId: id).content,
                reply: { _ in }
            ),
            Constants.chunkTimeout,
            { error in
                Current.Log.info("Could not cancel the Assist audio stream: \(error.localizedDescription)")
            }
        )
    }

    /// The iPhone stopped listening to this stream.
    public func phoneStoppedListening() {
        guard [.starting, .streaming].contains(mode) else { return }
        mode = .ended
        pendingAudio = Data()
        if !isSubmitted {
            onStopRecording?()
        }
    }

    private func sendNextChunkIfNeeded() {
        guard mode == .streaming, !isAwaitingAcknowledgement else { return }
        let isFinal = isSubmitted && pendingAudio.count <= Constants.maximumChunkSize
        guard isFinal || pendingAudio.count >= minimumChunkSize else { return }

        let audio = Data(pendingAudio.prefix(Constants.maximumChunkSize))
        pendingAudio = Data(pendingAudio.dropFirst(audio.count))
        let sequence = nextSequence
        nextSequence += 1
        isAwaitingAcknowledgement = true
        send(
            .init(
                identifier: InteractiveImmediateMessages.assistAudioStreamChunk.rawValue,
                content: AssistAudioStreamChunkPayload(
                    streamId: id,
                    sequence: sequence,
                    audio: audio,
                    isFinal: isFinal
                ).content,
                reply: { [weak self] reply in
                    self?.didAcknowledgeChunk(reply, isFinal: isFinal)
                }
            ),
            Constants.chunkTimeout,
            { [weak self] error in
                self?.didFailToSendChunk(error)
            }
        )
    }

    private func didAcknowledgeStart(_ reply: HAWatchConnectivity.ImmediateMessage) {
        // Not starting any more: it gave up waiting, or the recording already ended.
        guard mode == .starting else { return }
        guard let acknowledgement = AssistAudioStreamAckPayload(content: reply.content) else {
            sendWholeRecording(because: "the iPhone's answer to it could not be read")
            return
        }
        isAwaitingAcknowledgement = false
        guard acknowledgement.isListening else {
            // The iPhone could not start listening, and reports why with an Assist error.
            phoneStoppedListening()
            return
        }
        mode = .streaming
        sendNextChunkIfNeeded()
    }

    private func didFailToStart(_ error: Error) {
        guard mode == .starting else { return }
        sendWholeRecording(because: "\(error)")
    }

    private func sendWholeRecording(because reason: String) {
        Current.Log.info("Assist audio stream was not acknowledged, sending the whole recording: \(reason)")
        isAwaitingAcknowledgement = false
        mode = .buffering
    }

    private func didAcknowledgeChunk(_ reply: HAWatchConnectivity.ImmediateMessage, isFinal: Bool) {
        guard mode == .streaming else { return }
        isAwaitingAcknowledgement = false
        if isFinal {
            mode = .ended
        } else if AssistAudioStreamAckPayload(content: reply.content)?.isListening == true {
            sendNextChunkIfNeeded()
        } else {
            phoneStoppedListening()
        }
    }

    private func didFailToSendChunk(_ error: Error) {
        guard mode == .streaming else { return }
        Current.Log.error("Assist audio chunk \(nextSequence - 1) was not acknowledged: \(error)")
        isAwaitingAcknowledgement = false
        cancel()
        onFailure?(error)
    }
}
