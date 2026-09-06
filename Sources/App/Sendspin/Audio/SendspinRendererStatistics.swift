import Foundation

/// What the render thread has seen lately, sampled for diagnostics rather than control.
struct SendspinRendererStatistics: Equatable {
    let bufferedMilliseconds: Int
    let queuedChunks: Int
    let underruns: Int
    /// Signed timing error of the most recent correction: positive means the audio was early.
    let lastCorrectionMicroseconds: Double

    static let empty = SendspinRendererStatistics(
        bufferedMilliseconds: 0,
        queuedChunks: 0,
        underruns: 0,
        lastCorrectionMicroseconds: 0
    )
}
