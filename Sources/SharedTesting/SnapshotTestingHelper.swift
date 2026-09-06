import SwiftUI

import SnapshotTesting

/// How closely a render has to match its reference. Snapshots are captured through the render
/// server, so a little noise between machines is expected and the comparison is not exact.
public let defaultSnapshotPrecision: Float = 0.96

public func assertSnapshot<Value>(
    of value: @autoclosure () throws -> Value,
    drawHierarchyInKeyWindow: Bool = false,
    layout: SwiftUISnapshotLayout = SwiftUISnapshotLayout.device(config: .iPhone13(.portrait)),
    traits: UITraitCollection = .init(),
    named: String? = nil,
    precision: Float = defaultSnapshotPrecision,
    perceptualPrecision: Float = defaultSnapshotPrecision,
    record recording: Bool? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) where Value: SwiftUI.View {
    try assertSnapshot(
        of: value(),
        as: Snapshotting<Value, UIImage>.image(
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            layout: layout,
            traits: traits
        ),
        named: named,
        record: recording,
        timeout: timeout,
        fileID: fileID,
        file: filePath,
        testName: testName,
        line: line,
        column: column
    )
}

public func assertLightDarkSnapshots(
    of value: @autoclosure () throws -> some SwiftUI.View,
    drawHierarchyInKeyWindow: Bool = false,
    layout: SwiftUISnapshotLayout = SwiftUISnapshotLayout.device(config: .iPhone13(.portrait)),
    named: String? = nil,
    precision: Float = defaultSnapshotPrecision,
    perceptualPrecision: Float = defaultSnapshotPrecision,
    record recording: Bool? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) {
    for style in [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark] {
        let finalNamed: String
        if let named {
            finalNamed = "\(named)-\(style == .light ? "light" : "dark")"
        } else {
            finalNamed = style == .light ? "light" : "dark"
        }
        try assertSnapshot(
            of: value(),
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
            layout: layout,
            traits: .init(userInterfaceStyle: style),
            named: finalNamed,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            record: recording,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
