import CoreGraphics
@testable import Shared
import Testing

struct SVGPathTests {
    @Test("Absolute commands")
    func absoluteCommands() {
        let path = SVGPath.cgPath(from: "M2 2 L10 2 V10 H2 Z")
        #expect(path?.boundingBoxOfPath == CGRect(x: 2, y: 2, width: 8, height: 8))
    }

    @Test("Relative commands continue from the current point")
    func relativeCommands() {
        let path = SVGPath.cgPath(from: "m2 2 l8 0 v8 h-8 z")
        #expect(path?.boundingBoxOfPath == CGRect(x: 2, y: 2, width: 8, height: 8))
    }

    @Test("A command repeats over the arguments that follow it")
    func repeatedArguments() {
        let repeated = SVGPath.cgPath(from: "M0 0 L4 0 4 4 0 4 Z")
        let spelled = SVGPath.cgPath(from: "M0 0 L4 0 L4 4 L0 4 Z")
        #expect(repeated?.boundingBoxOfPath == spelled?.boundingBoxOfPath)
    }

    @Test("Numbers run together when the next one starts with a sign or a decimal point")
    func numbersWithoutSeparators() {
        let path = SVGPath.cgPath(from: "M.5.5L1.5.5 1.5 1.5-.5 1.5Z")
        #expect(path?.boundingBoxOfPath == CGRect(x: -0.5, y: 0.5, width: 2, height: 1))
    }

    @Test("An unsupported command gives up instead of returning half a path")
    func unsupportedCommand() {
        #expect(SVGPath.cgPath(from: "M0 0 A1 1 0 0 1 4 4") == nil)
        #expect(SVGPath.cgPath(from: "M0 0 Q1 1 2 2") == nil)
    }

    @Test("A path that does not start with a move is rejected")
    func mustStartWithMove() {
        #expect(SVGPath.cgPath(from: "L4 4") == nil)
        #expect(SVGPath.cgPath(from: "") == nil)
    }

    @Test("Every vendored brand icon parses inside its 24x24 box")
    func brandIconsParse() {
        for icon in BrandIcon.allCases {
            let box = SVGPath.cgPath(from: icon.pathData)?.boundingBoxOfPath
            #expect(box != nil, "\(icon.rawValue) failed to parse")
            guard let box else { continue }
            #expect(box.minX >= 0 && box.minY >= 0, "\(icon.rawValue) starts outside the box: \(box)")
            #expect(box.maxX <= 24 && box.maxY <= 24, "\(icon.rawValue) overflows the box: \(box)")
            #expect(box.width > 8 && box.height > 8, "\(icon.rawValue) is suspiciously small: \(box)")
        }
    }
}
