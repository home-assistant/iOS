import CoreGraphics
import Foundation

/// Builds a `CGPath` out of the `d` attribute of an SVG path.
///
/// Only the commands the vendored icons use are supported: move, line, horizontal line, vertical
/// line, cubic curve and close, in both their absolute and relative forms. Anything else returns
/// `nil` rather than a partial path, so a caller can fall back to another icon.
public enum SVGPath {
    public static func cgPath(from data: String) -> CGPath? {
        guard let commands = commands(in: data), let first = commands.first,
              first.name == "M" || first.name == "m" else {
            return nil
        }

        var pen = Pen()
        for command in commands {
            guard pen.apply(command) else { return nil }
        }
        return pen.path.isEmpty ? nil : pen.path.copy()
    }

    private struct Command {
        let name: Character
        let arguments: [CGFloat]

        var isRelative: Bool {
            name.isLowercase
        }
    }

    /// Walks the commands, keeping the current point the next relative command starts from.
    private struct Pen {
        let path = CGMutablePath()
        private var point: CGPoint = .zero
        private var subpathStart: CGPoint = .zero

        mutating func apply(_ command: Command) -> Bool {
            switch Character(command.name.uppercased()) {
            case "M": return addMove(command)
            case "L": return addLines(command)
            case "H": return addAxisLines(command, isHorizontal: true)
            case "V": return addAxisLines(command, isHorizontal: false)
            case "C": return addCurves(command)
            case "Z": return close(command)
            default: return false
            }
        }

        private mutating func addMove(_ command: Command) -> Bool {
            guard let points = pairs(of: command) else { return false }
            for (index, next) in points.enumerated() {
                if index == 0 {
                    path.move(to: next)
                    subpathStart = next
                } else {
                    path.addLine(to: next)
                }
                point = next
            }
            return true
        }

        private mutating func addLines(_ command: Command) -> Bool {
            guard let points = pairs(of: command) else { return false }
            for next in points {
                path.addLine(to: next)
                point = next
            }
            return true
        }

        private mutating func addAxisLines(_ command: Command, isHorizontal: Bool) -> Bool {
            guard !command.arguments.isEmpty else { return false }
            for value in command.arguments {
                let moved = command.isRelative ? (isHorizontal ? point.x : point.y) + value : value
                point = isHorizontal ? CGPoint(x: moved, y: point.y) : CGPoint(x: point.x, y: moved)
                path.addLine(to: point)
            }
            return true
        }

        private mutating func addCurves(_ command: Command) -> Bool {
            let arguments = command.arguments
            guard !arguments.isEmpty, arguments.count.isMultiple(of: 6) else { return false }
            for index in stride(from: 0, to: arguments.count, by: 6) {
                let control1 = resolve(arguments[index], arguments[index + 1], command)
                let control2 = resolve(arguments[index + 2], arguments[index + 3], command)
                let end = resolve(arguments[index + 4], arguments[index + 5], command)
                path.addCurve(to: end, control1: control1, control2: control2)
                point = end
            }
            return true
        }

        private mutating func close(_ command: Command) -> Bool {
            guard command.arguments.isEmpty else { return false }
            path.closeSubpath()
            point = subpathStart
            return true
        }

        /// The points of a command that takes coordinate pairs, each resolved against the point the
        /// command started from.
        private func pairs(of command: Command) -> [CGPoint]? {
            let arguments = command.arguments
            guard !arguments.isEmpty, arguments.count.isMultiple(of: 2) else { return nil }
            var points: [CGPoint] = []
            var start = point
            for index in stride(from: 0, to: arguments.count, by: 2) {
                let next = command.isRelative
                    ? CGPoint(x: start.x + arguments[index], y: start.y + arguments[index + 1])
                    : CGPoint(x: arguments[index], y: arguments[index + 1])
                points.append(next)
                start = next
            }
            return points
        }

        private func resolve(_ x: CGFloat, _ y: CGFloat, _ command: Command) -> CGPoint {
            command.isRelative ? CGPoint(x: point.x + x, y: point.y + y) : CGPoint(x: x, y: y)
        }
    }

    private static func commands(in data: String) -> [Command]? {
        var commands: [Command] = []
        var name: Character?
        var arguments: [CGFloat] = []
        var index = data.startIndex

        while index < data.endIndex {
            let character = data[index]
            if character.isLetter {
                if let name {
                    commands.append(Command(name: name, arguments: arguments))
                }
                name = character
                arguments = []
                index = data.index(after: index)
            } else if character == "," || character.isWhitespace {
                index = data.index(after: index)
            } else if let number = number(in: data, from: index) {
                arguments.append(number.value)
                index = number.end
            } else {
                return nil
            }
        }

        if let name {
            commands.append(Command(name: name, arguments: arguments))
        }
        return commands
    }

    /// Reads one number, stopping where the next one starts. SVG lets numbers run together when the
    /// next one begins with a sign or, for a fraction, with its own decimal point.
    private static func number(in data: String, from start: String.Index) -> (value: CGFloat, end: String.Index)? {
        var index = start
        var digits = ""
        var hasDecimalPoint = false

        if data[index] == "-" || data[index] == "+" {
            digits.append(data[index])
            index = data.index(after: index)
        }

        while index < data.endIndex {
            let character = data[index]
            if character.isNumber {
                digits.append(character)
            } else if character == ".", !hasDecimalPoint {
                hasDecimalPoint = true
                digits.append(character)
            } else {
                break
            }
            index = data.index(after: index)
        }

        guard let value = Double(digits) else { return nil }
        return (CGFloat(value), index)
    }
}
