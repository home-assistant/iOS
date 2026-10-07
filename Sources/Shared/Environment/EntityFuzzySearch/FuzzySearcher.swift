import Foundation

struct FuzzySearcher: Sendable {
    private struct FieldMatch {
        let weight: Double
        let norm: Double
        let score: Double
    }

    private let normalizedWeights: [Double]
    private let options: BitapSearcher.Options

    init(keys: [FuzzyKey], options: BitapSearcher.Options = BitapSearcher.Options()) {
        let total = keys.reduce(0) { $0 + $1.weight }
        self.normalizedWeights = keys.map { total > 0 ? $0.weight / total : 0 }
        self.options = options
    }

    func search(_ query: String, in documents: [FuzzyDocument]) -> [Int] {
        let substrings: [Substring] = query.lowercased().split(separator: " ")
        let terms: [String] = substrings.map(String.init).filter { !$0.isEmpty }
        if terms.isEmpty { return Array(documents.indices) }

        if terms.count == 1 {
            let results = searchTerm(terms[0], in: documents)
            let sorted = results.sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.index < rhs.index : lhs.score < rhs.score
            }
            return sorted.map(\.index)
        }

        var aggregate: [Int: (hits: Int, score: Double)] = [:]
        var termHits = 0
        for term in terms {
            let results = searchTerm(term, in: documents)
            if results.isEmpty { continue }
            termHits += 1
            for result in results {
                let contribution = -log(result.score == 0 ? Double.leastNonzeroMagnitude : result.score)
                if var existing = aggregate[result.index] {
                    existing.hits += 1
                    existing.score += contribution
                    aggregate[result.index] = existing
                } else {
                    aggregate[result.index] = (1, contribution)
                }
            }
        }
        if termHits != terms.count { return [] }
        let matched = aggregate.filter { $0.value.hits == terms.count }
        let sorted = matched.sorted { lhs, rhs in
            lhs.value.score == rhs.value.score ? lhs.key < rhs.key : lhs.value.score > rhs.value.score
        }
        return sorted.map(\.key)
    }

    private func searchTerm(_ term: String, in documents: [FuzzyDocument]) -> [(index: Int, score: Double)] {
        var options = options
        let termLength = term.utf16.count
        if termLength < options.minMatchCharLength { options.minMatchCharLength = termLength }
        let searcher = BitapSearcher(pattern: term, options: options)

        var results: [(index: Int, score: Double)] = []
        for (documentIndex, document) in documents.enumerated() {
            var matches: [FieldMatch] = []
            for (keyIndex, weight) in normalizedWeights.enumerated() {
                guard keyIndex < document.fieldValues.count,
                      let value = document.fieldValues[keyIndex], !value.isEmpty else { continue }
                let result = searcher.searchIn(value)
                if result.isMatch {
                    matches.append(FieldMatch(weight: weight, norm: FuzzyFieldNorm.value(value), score: result.score))
                }
            }
            if !matches.isEmpty {
                results.append((documentIndex, combinedScore(matches)))
            }
        }
        return results
    }

    private func combinedScore(_ matches: [FieldMatch]) -> Double {
        var total = 1.0
        for match in matches {
            let base = match.score == 0 ? Double.ulpOfOne : match.score
            total *= pow(base, match.weight * match.norm)
        }
        return total
    }
}
