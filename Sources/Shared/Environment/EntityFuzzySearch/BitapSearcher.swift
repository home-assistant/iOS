import Foundation

struct BitapSearcher {
    struct Options: Sendable {
        var location = 0
        var threshold = 0.3
        var distance = 100
        var findAllMatches = false
        var minMatchCharLength = 2
        var ignoreLocation = true
    }

    struct Result {
        var isMatch: Bool
        var score: Double
    }

    private static let maxBits = 32

    let options: Options
    private let normalizedPattern: String
    private let chunks: [(pattern: [UInt16], alphabet: [UInt16: Int])]

    init(pattern: String, options: Options) {
        self.options = options
        let normalized = FuzzyTextNormalizer.normalize(pattern)
        self.normalizedPattern = normalized
        let units = FuzzyTextNormalizer.units(normalized)
        var chunks: [(pattern: [UInt16], alphabet: [UInt16: Int])] = []
        if !units.isEmpty {
            let len = units.count
            if len > Self.maxBits {
                var i = 0
                let remainder = len % Self.maxBits
                let end = len - remainder
                while i < end {
                    let sub = Array(units[i ..< (i + Self.maxBits)])
                    chunks.append((sub, Self.createPatternAlphabet(sub)))
                    i += Self.maxBits
                }
                if remainder != 0 {
                    let startIndex = len - Self.maxBits
                    let sub = Array(units[startIndex...])
                    chunks.append((sub, Self.createPatternAlphabet(sub)))
                }
            } else {
                chunks.append((units, Self.createPatternAlphabet(units)))
            }
        }
        self.chunks = chunks
    }

    func searchIn(_ text: String) -> Result {
        let normalizedText = FuzzyTextNormalizer.normalize(text)
        if normalizedPattern == normalizedText {
            return Result(isMatch: true, score: 0)
        }
        if chunks.isEmpty {
            return Result(isMatch: false, score: 1)
        }
        let textUnits = FuzzyTextNormalizer.units(normalizedText)
        var totalScore = 0.0
        var hasMatches = false
        for chunk in chunks {
            let result = Self.search(
                text: textUnits,
                pattern: chunk.pattern,
                patternAlphabet: chunk.alphabet,
                options: options
            )
            if result.isMatch { hasMatches = true }
            totalScore += result.score
        }
        return Result(isMatch: hasMatches, score: hasMatches ? totalScore / Double(chunks.count) : 1)
    }

    private static func createPatternAlphabet(_ pattern: [UInt16]) -> [UInt16: Int] {
        var mask: [UInt16: Int] = [:]
        let len = pattern.count
        for i in 0 ..< len {
            let character = pattern[i]
            mask[character] = (mask[character] ?? 0) | (1 << (len - i - 1))
        }
        return mask
    }

    private static func indexOf(_ text: [UInt16], _ pattern: [UInt16], from: Int) -> Int {
        let textCount = text.count
        let patternCount = pattern.count
        if patternCount == 0 { return from <= textCount ? from : -1 }
        if patternCount > textCount { return -1 }
        var i = max(0, from)
        while i <= textCount - patternCount {
            var j = 0
            while j < patternCount, text[i + j] == pattern[j] {
                j += 1
            }
            if j == patternCount { return i }
            i += 1
        }
        return -1
    }

    private static func hasMatchRun(_ matchMask: [Int], minMatchCharLength: Int) -> Bool {
        var start = -1
        var index = 0
        let count = matchMask.count
        while index < count {
            let match = matchMask[index]
            if match != 0, start == -1 {
                start = index
            } else if match == 0, start != -1 {
                if index - start >= minMatchCharLength { return true }
                start = -1
            }
            index += 1
        }
        if count > 0, matchMask[index - 1] != 0, index - start >= minMatchCharLength {
            return true
        }
        return false
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func search(
        text: [UInt16],
        pattern: [UInt16],
        patternAlphabet: [UInt16: Int],
        options: Options
    ) -> Result {
        let patternLen = pattern.count
        let textLen = text.count
        let expectedLocation = max(0, min(options.location, textLen))
        var currentThreshold = options.threshold
        var bestLocation = expectedLocation
        let distance = options.distance
        let ignoreLocation = options.ignoreLocation

        func calcScore(_ errors: Int, _ currentLocation: Int) -> Double {
            let accuracy = Double(errors) / Double(patternLen)
            if ignoreLocation { return accuracy }
            let proximity = abs(expectedLocation - currentLocation)
            if distance == 0 { return proximity != 0 ? 1.0 : accuracy }
            return accuracy + Double(proximity) / Double(distance)
        }

        func safe(_ array: [Int], _ index: Int) -> Int {
            (index >= 0 && index < array.count) ? array[index] : 0
        }

        let computeMatches = options.minMatchCharLength > 1
        var matchMask = [Int](repeating: 0, count: textLen)

        var occurrence = indexOf(text, pattern, from: bestLocation)
        while occurrence > -1 {
            let score = calcScore(0, occurrence)
            currentThreshold = min(score, currentThreshold)
            bestLocation = occurrence + patternLen
            if computeMatches {
                var offset = 0
                while offset < patternLen {
                    matchMask[occurrence + offset] = 1; offset += 1
                }
            }
            occurrence = indexOf(text, pattern, from: bestLocation)
        }

        bestLocation = -1
        var lastBitArray: [Int] = []
        var finalScore = 1.0
        var bestErrors = 0
        var binMax = patternLen + textLen
        let mask = 1 << (patternLen - 1)

        for i in 0 ..< patternLen {
            var binMin = 0
            var binMid = binMax
            while binMin < binMid {
                let score = calcScore(i, expectedLocation + binMid)
                if score <= currentThreshold {
                    binMin = binMid
                } else {
                    binMax = binMid
                }
                binMid = (binMax - binMin) / 2 + binMin
            }
            binMax = binMid

            var start = max(1, expectedLocation - binMid + 1)
            let finish = options.findAllMatches ? textLen : min(expectedLocation + binMid, textLen) + patternLen

            var bitArray = [Int](repeating: 0, count: finish + 2)
            bitArray[finish + 1] = (1 << i) - 1

            var j = finish
            while j >= start {
                let currentLocation = j - 1
                let charMatch: Int = {
                    if currentLocation >= 0, currentLocation < textLen {
                        return patternAlphabet[text[currentLocation]] ?? 0
                    }
                    return 0
                }()

                bitArray[j] = ((safe(bitArray, j + 1) << 1) | 1) & charMatch
                if i != 0 {
                    bitArray[j] |= ((safe(lastBitArray, j + 1) | safe(lastBitArray, j)) << 1) | 1 | safe(
                        lastBitArray,
                        j + 1
                    )
                }

                if bitArray[j] & mask != 0 {
                    finalScore = calcScore(i, currentLocation)
                    if finalScore <= currentThreshold {
                        currentThreshold = finalScore
                        bestLocation = currentLocation
                        bestErrors = i
                        if bestLocation <= expectedLocation { break }
                        start = max(1, 2 * expectedLocation - bestLocation)
                    }
                }
                j -= 1
            }

            if calcScore(i + 1, expectedLocation) > currentThreshold { break }
            lastBitArray = bitArray
        }

        if computeMatches, bestLocation >= 0 {
            let matchEnd = min(textLen - 1, bestLocation + patternLen - 1 + bestErrors)
            var k = bestLocation
            while k <= matchEnd {
                if k >= 0, k < textLen, (patternAlphabet[text[k]] ?? 0) != 0 {
                    matchMask[k] = 1
                }
                k += 1
            }
        }

        var isMatch = bestLocation >= 0
        if computeMatches, !hasMatchRun(matchMask, minMatchCharLength: options.minMatchCharLength) {
            isMatch = false
        }

        return Result(isMatch: isMatch, score: max(0.001, finalScore))
    }
}
