import Foundation

public enum EntityColorAttributesParser {
    public typealias ParsedAttributes = (
        colorMode: String?,
        rgbColor: [Int]?,
        hsColor: [Double]?
    )

    public static func parse(from attributes: [String: Any]?) -> ParsedAttributes {
        guard let attributes else {
            return (nil, nil, nil)
        }

        return (
            colorMode: attributes["color_mode"] as? String,
            rgbColor: parseRGBColor(from: attributes["rgb_color"]),
            hsColor: parseHSColor(from: attributes["hs_color"])
        )
    }

    public static func parseRGBColor(from value: Any?) -> [Int]? {
        if let rgb = value as? [Int], rgb.count == 3 {
            return rgb
        }

        if let rgbAny = value as? [Any] {
            let ints = rgbAny.compactMap { value -> Int? in
                if let int = value as? Int {
                    return int
                }
                if let number = value as? NSNumber {
                    return number.intValue
                }
                if let string = value as? String {
                    return Int(string)
                }
                return nil
            }
            return ints.count == 3 ? ints : nil
        }

        return nil
    }

    public static func parseHSColor(from value: Any?) -> [Double]? {
        if let hs = value as? [Double], hs.count >= 2 {
            return Array(hs.prefix(2))
        }

        if let hsAny = value as? [Any] {
            let doubles = hsAny.compactMap { value -> Double? in
                if let double = value as? Double {
                    return double
                }
                if let number = value as? NSNumber {
                    return number.doubleValue
                }
                if let string = value as? String {
                    return Double(string)
                }
                return nil
            }
            return doubles.count >= 2 ? Array(doubles.prefix(2)) : nil
        }

        return nil
    }
}
