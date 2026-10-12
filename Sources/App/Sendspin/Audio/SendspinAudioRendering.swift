import Foundation

/// What a session drives to play its stream. A protocol so tests can check what was played
/// without opening the audio hardware.
protocol SendspinAudioRendering: AnyObject, Sendable {
    func start(format: SendspinStreamFormat) throws
    func stop()
    func clear()
    func enqueue(_ chunk: SendspinAudioChunk)
    func update(mapping: SendspinClockMapping)
    func setOutputDelay(milliseconds: Int)
    func setVolume(_ volume: Int, muted: Bool)
}
