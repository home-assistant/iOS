import Foundation

enum FuzzyTextNormalizer {
    private static let combiningMarks: ClosedRange<UInt32> = 0x0300 ... 0x036F

    static func normalize(_ string: String) -> String {
        let decomposed = string.lowercased().decomposedStringWithCanonicalMapping
        var scalars = String.UnicodeScalarView()
        for scalar in decomposed.unicodeScalars where !combiningMarks.contains(scalar.value) {
            scalars.append(scalar)
        }
        return String(scalars)
    }

    static func units(_ normalized: String) -> [UInt16] {
        Array(normalized.utf16)
    }
}
