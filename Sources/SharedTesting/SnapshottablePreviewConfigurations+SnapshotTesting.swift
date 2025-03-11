import SnapshotTesting

import Shared

public extension SnapshottablePreviewConfigurations {
    func assertSnapshots(
        layout: SwiftUISnapshotLayout,
        traits: UITraitCollection,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        for configuration in configurations {
            assertSnapshot(
                of: view(configuration.item),
                as: .image(layout: layout, traits: traits),
                named: configuration.name,
                fileID: fileID,
                file: filePath,
                testName: testName,
                line: line,
                column: column
            )
        }
    }
}
