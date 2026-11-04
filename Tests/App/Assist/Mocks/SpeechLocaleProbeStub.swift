import Foundation

/// Stands in for the speech daemon: each probe gets the next answer, and the last one repeats,
/// which is how a dictation language installed while the app runs looks from the app's side.
final class SpeechLocaleProbeStub: @unchecked Sendable {
    private let lock = NSLock()
    private let answers: [[Locale]]
    private var count = 0

    init(answers: [[Locale]]) {
        self.answers = answers
    }

    var probeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func probe() -> [Locale] {
        lock.lock()
        defer { lock.unlock() }
        let answer = answers[min(count, answers.count - 1)]
        count += 1
        return answer
    }
}
