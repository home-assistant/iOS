import SwiftUI
import UIKit

import SnapshotTesting

func assertLightDarkSnapshots<Value>(
    of value: @autoclosure () throws -> Value,
    layout: SwiftUISnapshotLayout = SwiftUISnapshotLayout.device(config: .iPhone13(.portrait)),
    record recording: Bool? = nil,
    timeout: TimeInterval = 5,
    fileID: StaticString = #fileID,
    file filePath: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line,
    column: UInt = #column
) where Value: SwiftUI.View {
    for style in [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark] {
        try assertSnapshot(
            of: value(),
            as: Snapshotting<Value, UIImage>.image(
                layout: layout,
                traits: .init(userInterfaceStyle: style)
            ),
            record: recording,
            timeout: timeout,
            fileID: fileID,
            file: filePath,
            testName: "\(testName)-\(style == .light ? "light" : "dark")",
            line: line,
            column: column
        )
    }
}
