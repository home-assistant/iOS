import SnapshotTesting

import Shared

public extension SnapshottablePreviewConfigurations {
    func assertSnapshots(
        drawHierarchyInKeyWindow: Bool = false,
        layout: SwiftUISnapshotLayout = SwiftUISnapshotLayout.device(config: .iPhone13(.portrait)),
        traits: UITraitCollection = .init(),
        record recording: Bool = false,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        for configuration in configurations {
            assertSnapshot(
                of: view(configuration.item),
                drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
                layout: layout,
                traits: traits,
                named: configuration.name,
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

    func assertLightDarkSnapshots(
        drawHierarchyInKeyWindow: Bool = false,
        layout: SwiftUISnapshotLayout = SwiftUISnapshotLayout.device(config: .iPhone13(.portrait)),
        record recording: Bool = false,
        timeout: TimeInterval = 5,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        for configuration in configurations {
            SharedTesting.assertLightDarkSnapshots(
                of: view(configuration.item),
                drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
                layout: layout,
                named: configuration.name,
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
}
