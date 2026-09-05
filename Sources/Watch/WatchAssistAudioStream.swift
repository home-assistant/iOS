import Foundation
import Shared

/// Relays one recording streamed live from the watch into an Assist pipeline run.
///
/// Chunks arrive before the pipeline is ready to take audio (the run starts on the first chunk,
/// and `run-start` comes back later), so they are buffered until the green light and flushed in
/// order. From then on each chunk goes straight through. Once the pipeline stops listening — its
/// voice-activity detection ended the command, speech-to-text finished, or the run failed — the
/// audio is finished once and every later chunk is answered with `keepListening == false`, which
/// is what makes the watch stop recording.
///
/// Chunks come in on WatchConnectivity's queue and pipeline events on HAKit's, so the state is
/// kept under a lock.
final class WatchAssistAudioStream {
    let recordingId: String
    /// Chunks that stop for this long mean the watch went away mid-recording: the audio is
    /// finished so the pipeline processes what it has instead of waiting for its own timeout.
    static let staleTimeout: TimeInterval = 10

    private let sendAudio: (Data) -> Void
    private let finishAudio: () -> Void

    private let lock = NSLock()
    private var buffered: [Data] = []
    private var hasGreenLight = false
    private var isListening = true
    private var watchEnded = false
    private var didFinish = false
    private var _lastChunkAt: Date

    /// - Parameters:
    ///   - sendAudio: forwards one chunk to the pipeline (`AssistService.sendAudioData`).
    ///   - finishAudio: tells the pipeline the audio is complete (`AssistService.finishSendingAudio`).
    init(
        recordingId: String,
        now: Date,
        sendAudio: @escaping (Data) -> Void,
        finishAudio: @escaping () -> Void
    ) {
        self.recordingId = recordingId
        self._lastChunkAt = now
        self.sendAudio = sendAudio
        self.finishAudio = finishAudio
    }

    var lastChunkAt: Date {
        lock.lock()
        defer { lock.unlock() }
        return _lastChunkAt
    }

    /// The pipeline was told the audio is complete; nothing else will be sent.
    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didFinish
    }

    /// A chunk from the watch. Returns whether the pipeline still listens, which is what the
    /// acknowledgement carries back.
    func receive(chunk: Data, now: Date) -> Bool {
        lock.lock()
        _lastChunkAt = now
        guard isListening, !watchEnded else {
            lock.unlock()
            return false
        }
        if hasGreenLight {
            lock.unlock()
            sendAudio(chunk)
        } else {
            buffered.append(chunk)
            lock.unlock()
        }
        return true
    }

    /// `run-start` delivered the binary handler: flush what was buffered, in order.
    func pipelineDidStartAcceptingAudio() {
        lock.lock()
        hasGreenLight = true
        let toFlush = buffered
        buffered.removeAll()
        let finishNow = isListening && watchEnded && !didFinish
        if finishNow { didFinish = true }
        lock.unlock()

        toFlush.forEach(sendAudio)
        if finishNow {
            finishAudio()
        }
    }

    /// The pipeline stopped taking audio. Finishing the audio here is what lets a recording that
    /// the watch has not ended yet complete; once done, later chunks are answered with "stop".
    func pipelineDidStopListening() {
        lock.lock()
        isListening = false
        buffered.removeAll()
        let finishNow = hasGreenLight && !didFinish
        if finishNow { didFinish = true }
        lock.unlock()

        if finishNow {
            finishAudio()
        }
    }

    /// The recording ended on the watch (or its chunks went stale). Finishes the audio if the
    /// pipeline is ready for it; otherwise the flush on the green light does.
    func watchDidEnd() {
        lock.lock()
        watchEnded = true
        let finishNow = hasGreenLight && isListening && !didFinish
        if finishNow { didFinish = true }
        lock.unlock()

        if finishNow {
            finishAudio()
        }
    }
}
