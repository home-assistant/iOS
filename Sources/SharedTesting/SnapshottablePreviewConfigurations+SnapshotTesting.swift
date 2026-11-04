import SnapshotTesting

import Shared

/// Snapshots every configuration a preview declares, so a preview that gains a case gains its
/// references with it.
///
/// `recording` defaults to `nil` rather than `false` so these follow whatever the run is configured
/// to record — `false` pins them to "only what is missing", which leaves a reference that no longer
/// matches failing forever with no way to re-record it.
public extension SnapshottablePreviewConfigurations {
    func assertSnapshots(
        drawHierarchyInKeyWindow: Bool = false,
        layout: SwiftUISnapshotLayout = SwiftUISnapshotLayout.device(config: .iPhone13(.portrait)),
        traits: UITraitCollection = .init(),
        record recording: Bool? = nil,
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
        record recording: Bool? = nil,
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
