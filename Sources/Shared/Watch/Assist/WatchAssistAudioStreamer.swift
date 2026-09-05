import Foundation

/// Streams one Assist recording from the watch to the phone while it is still being captured, so
/// the pipeline's own voice-activity detection decides when the user stopped talking.
///
/// Audio is handed in as it is captured (`enqueue`) and goes out as `assistAudioStreamChunk`
/// messages, one at a time: the next chunk leaves only after the phone acknowledged the previous
/// one, and carries everything captured in between (capped at `Constants.maxChunkBytes`), so the
/// stream paces itself to whatever the link sustains instead of flooding the session. Each
/// acknowledgement doubles as the phone's answer to "is the pipeline still listening?": the first
/// `keepListening == false` ends the stream and fires `onStopListening`, which is the recorder's
/// cue to stop. Once the recording is over on the watch side (`end`), the remaining audio is
/// flushed and an `assistAudioStreamEnd` message tells the phone the audio is complete.
///
/// Callbacks fire on whatever queue the audio or the reply arrived on; callers hop to the main
/// queue themselves.
public final class WatchAssistAudioStreamer {
    public enum Constants {
        /// Ceiling per message: WatchConnectivity's `sendMessage` payload limit is about 64 KB.
        public static let maxChunkBytes = 32 * 1024
        /// A chunk waits until at least this much audio accumulated (a quarter second of 16 kHz
        /// 16-bit mono) so a fast link does not cost a message per capture buffer. The last chunk
        /// of a recording goes out regardless of size.
        public static let minChunkBytes = 8000
    }

    public enum Phase: Equatable {
        /// Capturing: audio is accepted and streamed.
        case streaming
        /// The recording ended on the watch, or the phone said to stop: what is buffered still
        /// goes out, followed by the end message.
        case ending
        /// The end message went out, or the stream failed. Nothing is sent any more.
        case ended
    }

    public let recordingId: String
    /// Fires once, when the phone reports the pipeline stopped taking audio.
    public var onStopListening: (() -> Void)?
    /// Fires once, on the first delivery failure. The stream is over; the recording should stop.
    public var onError: ((Error) -> Void)?

    public var phase: Phase {
        lock.lock()
        defer { lock.unlock() }
        return _phase
    }

    private let serverId: String
    private let pipelineId: String
    private let sampleRate: Double
    private let sender: WatchAssistAudioStreamSending

    /// Audio arrives on the capture queue and replies on WatchConnectivity's, so every piece of
    /// state is read and written under this lock, and callbacks fire only after it is released.
    private let lock = NSLock()
    private var _phase: Phase = .streaming
    private var pending = Data()
    private var inFlight = false
    private var nextChunkIndex = 0
    private var didReportStop = false

    public init(
        recordingId: String = UUID().uuidString,
        serverId: String,
        pipelineId: String,
        sampleRate: Double,
        sender: WatchAssistAudioStreamSending
    ) {
        self.recordingId = recordingId
        self.serverId = serverId
        self.pipelineId = pipelineId
        self.sampleRate = sampleRate
        self.sender = sender
    }

    /// Hand over audio captured since the previous call. Ignored once the stream is ending.
    public func enqueue(audio: Data) {
        lock.lock()
        guard _phase == .streaming else {
            lock.unlock()
            return
        }
        pending.append(audio)
        let send = nextSendLocked()
        lock.unlock()
        perform(send)
    }

    /// The recording ended on the watch: flush what is buffered, then tell the phone. Safe to call
    /// more than once, and after the phone already asked to stop.
    public func end() {
        lock.lock()
        guard _phase == .streaming else {
            lock.unlock()
            return
        }
        _phase = .ending
        let send = nextSendLocked()
        lock.unlock()
        perform(send)
    }

    private enum Send {
        case chunk(Data, index: Int)
        case end
    }

    /// Decide what goes out next, if anything. Must be called with the lock held; the caller
    /// performs the send after releasing it.
    private func nextSendLocked() -> Send? {
        guard !inFlight, _phase != .ended else { return nil }
        let ending = _phase == .ending
        if !pending.isEmpty, ending || pending.count >= Constants.minChunkBytes {
            let chunk = pending.prefix(Constants.maxChunkBytes)
            pending.removeFirst(chunk.count)
            let index = nextChunkIndex
            nextChunkIndex += 1
            inFlight = true
            return .chunk(Data(chunk), index: index)
        }
        if ending {
            _phase = .ended
            inFlight = true
            return .end
        }
        return nil
    }

    private func perform(_ send: Send?) {
        guard let send else { return }
        switch send {
        case let .chunk(data, index):
            sender.sendAssistAudioStreamMessage(
                .init(
                    identifier: InteractiveImmediateMessages.assistAudioStreamChunk.rawValue,
                    content: AssistAudioStreamChunkPayload(
                        recordingId: recordingId,
                        chunkIndex: index,
                        chunkData: data,
                        sampleRate: sampleRate,
                        pipelineId: pipelineId,
                        serverId: serverId
                    ).content,
                    reply: { [weak self] reply in
                        self?.handleChunkReply(reply, index: index)
                    }
                ),
                errorHandler: { [weak self] error in
                    self?.fail(error, describing: "chunk \(index)")
                }
            )
        case .end:
            sender.sendAssistAudioStreamMessage(
                .init(
                    identifier: InteractiveImmediateMessages.assistAudioStreamEnd.rawValue,
                    content: AssistAudioStreamEndPayload(recordingId: recordingId).content,
                    reply: { _ in
                        Current.Log.verbose("Assist audio stream end acknowledged")
                    }
                ),
                errorHandler: { error in
                    // The pipeline stops listening on its own once the audio dries up; the
                    // recording is already over, so there is nothing to tear down.
                    Current.Log.error(
                        "Assist audio stream end failed to reach the iPhone: \(error.localizedDescription)"
                    )
                }
            )
        }
    }

    private func handleChunkReply(_ reply: HAWatchConnectivity.ImmediateMessage, index: Int) {
        // A reply that is not an ack (a phone build without the payload) is treated as "keep
        // going": the watch's duration cap still bounds the recording.
        let keepListening = AssistAudioStreamChunkAckPayload(content: reply.content)?.keepListening ?? true

        lock.lock()
        inFlight = false
        var reportStop = false
        if !keepListening, _phase == .streaming {
            // The pipeline is no longer reading: whatever was captured since is of no use to it,
            // and dropping it gets the end message out sooner.
            pending.removeAll()
            _phase = .ending
            reportStop = !didReportStop
            didReportStop = true
        }
        let send = nextSendLocked()
        lock.unlock()

        if reportStop {
            Current.Log.info("Assist pipeline stopped listening after chunk \(index)")
            onStopListening?()
        }
        perform(send)
    }

    private func fail(_ error: Error, describing what: String) {
        lock.lock()
        let alreadyEnded = _phase == .ended
        _phase = .ended
        inFlight = false
        pending.removeAll()
        lock.unlock()

        Current.Log.error("Assist audio stream \(what) failed: \(error.localizedDescription)")
        guard !alreadyEnded else { return }
        onError?(error)
    }
}
