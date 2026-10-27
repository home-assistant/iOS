import Foundation
@testable import HomeAssistant

/// Records what a session asked the audio output to do.
final class SendspinFakeAudio: SendspinAudioRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var _started: [SendspinStreamFormat] = []
    private var _enqueued: [SendspinAudioChunk] = []
    private var _stopCount = 0
    private var _clearCount = 0
    private var _volume: (Int, Bool)?
    private var _outputDelay: Int?
    private var _mapping: SendspinClockMapping?

    var started: [SendspinStreamFormat] { lock.withLock { _started } }
    var enqueued: [SendspinAudioChunk] { lock.withLock { _enqueued } }
    var stopCount: Int { lock.withLock { _stopCount } }
    var clearCount: Int { lock.withLock { _clearCount } }
    var volume: (Int, Bool)? { lock.withLock { _volume } }
    var outputDelay: Int? { lock.withLock { _outputDelay } }
    var mapping: SendspinClockMapping? { lock.withLock { _mapping } }

    func start(format: SendspinStreamFormat) throws {
        lock.withLock { _started.append(format) }
    }

    func stop() {
        lock.withLock { _stopCount += 1 }
    }

    func clear() {
        lock.withLock { _clearCount += 1 }
    }

    func enqueue(_ chunk: SendspinAudioChunk) {
        lock.withLock { _enqueued.append(chunk) }
    }

    func update(mapping: SendspinClockMapping) {
        lock.withLock { _mapping = mapping }
    }

    func setOutputDelay(milliseconds: Int) {
        lock.withLock { _outputDelay = milliseconds }
    }

    func setVolume(_ volume: Int, muted: Bool) {
        lock.withLock { _volume = (volume, muted) }
    }
}
