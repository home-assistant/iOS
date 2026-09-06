import Foundation
@testable import HomeAssistant
import Testing

struct ManageStorageSourceTests {
    @Test func onlyFileBackedSourcesReportPaths() {
        let folder = URL(fileURLWithPath: "/tmp/manage-storage")

        #expect(ManageStorageSource.files([folder]).urls == [folder])
        #expect(ManageStorageSource.webKit(urls: [folder], dataTypes: ["type"]).urls == [folder])
        #expect(ManageStorageSource.networkResponseCache.urls.isEmpty)
        #expect(ManageStorageSource.databaseTables(["table"]).urls.isEmpty)
    }
}
