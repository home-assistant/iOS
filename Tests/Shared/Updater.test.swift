import OHHTTPStubs
import PromiseKit
@testable import Shared
import Version
import XCTest

class UpdaterTest: XCTestCase {
    private var stubDescriptors: [HTTPStubsDescriptor] = []
    private var updater: Updater!

    override func setUp() {
        super.setUp()

        updater = Updater()
    }

    override func tearDown() {
        super.tearDown()
        removeDescriptors()
    }

    private func removeDescriptors() {
        for descriptor in stubDescriptors {
            HTTPStubs.removeStub(descriptor)
        }
    }

    private enum Expected {
        case updateError(Updater.UpdateError)
        case networkError(URLError.Code)
        case hasUpdate(Int)
    }

    func testNetworkError() {
        compare(
            versions: .failure(URLError(.timedOut)),
            currentVersion: .init(major: 2021, minor: 1, patch: 0, build: "1"),
            expecting: .networkError(.timedOut)
        )
    }

    func testNoVersions() {
        compare(
            versions: .success([]),
            currentVersion: .init(major: 2021, minor: 1, patch: 0, build: "1"),
            expecting: .updateError(.onLatestVersion)
        )
    }

    func testLatestAvailableSameBuild() {
        compare(
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "5"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "5"),
            expecting: .updateError(.onLatestVersion)
        )
    }

    func testLatestAvailableOlderBuilds() {
        compare(
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "1"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "2"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "3"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "4"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "5"),
            expecting: .updateError(.onLatestVersion)
        )
    }

    func testLatestAvailableNewerBuild() {
        compare(
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "1"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "2"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "3"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "4"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "3"),
            expecting: .hasUpdate(3)
        )
    }

    func testLatestAvailableNewerVersion() {
        compare(
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "1"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "2"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "3"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "4"),
                .init(hasAsset: true, prerelease: false, version: "2021.6", build: "1"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "3"),
            expecting: .hasUpdate(4)
        )
    }

    func testPrereleaseChecking() {
        let versions: [AvailableUpdate] = [
            .init(hasAsset: true, prerelease: false, version: "2021.5", build: "1"),
            .init(hasAsset: true, prerelease: false, version: "2021.5", build: "2"),
            .init(hasAsset: true, prerelease: false, version: "2021.5", build: "3"),
            .init(hasAsset: true, prerelease: true, version: "2021.5", build: "4"),
        ]

        compare(
            allowPrerelease: false,
            versions: .success(versions),
            currentVersion: .init(major: 2021, minor: 5, build: "2"),
            expecting: .hasUpdate(2)
        )

        compare(
            allowPrerelease: true,
            versions: .success(versions),
            currentVersion: .init(major: 2021, minor: 5, build: "2"),
            expecting: .hasUpdate(3)
        )
    }

    func testIgnoresWithoutAssets() {
        compare(
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "4"),
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "5"),
                .init(hasAsset: false, prerelease: false, version: "2021.5", build: "6"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "4"),
            expecting: .hasUpdate(1)
        )
    }

    func testUpdatePreference() {
        compare(
            dueToUserInteraction: false,
            allowUpdates: false,
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "5"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "1"),
            expecting: .updateError(.privacyDisabled)
        )

        compare(
            dueToUserInteraction: true,
            allowUpdates: false,
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "5"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "1"),
            expecting: .hasUpdate(0)
        )
    }

    func testAppStore() {
        compare(
            isAppStore: true,
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "5"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "1"),
            expecting: .updateError(.unsupportedPlatform)
        )
    }

    func testNotCatalyst() {
        compare(
            isCatalyst: false,
            versions: .success([
                .init(hasAsset: true, prerelease: false, version: "2021.5", build: "5"),
            ]),
            currentVersion: .init(major: 2021, minor: 5, build: "1"),
            expecting: .updateError(.unsupportedPlatform)
        )
    }

    private func compare(
        isCatalyst: Bool = true,
        isAppStore: Bool = false,
        dueToUserInteraction: Bool = false,
        allowUpdates: Bool = true,
        allowPrerelease: Bool = true,
        versions: Swift.Result<[AvailableUpdate], Error>,
        currentVersion: Version,
        expecting: Expected
    ) {
        Current.isCatalyst = isCatalyst
        Current.isAppStore = isAppStore
        Current.clientVersion = { currentVersion }
        Current.settingsStore.privacy.updates = allowUpdates
        Current.settingsStore.privacy.updatesIncludeBetas = allowPrerelease

        let url = URL(string: "https://api.github.com/repos/home-assistant/ios/releases?per_page=25")!
        removeDescriptors()
        stubDescriptors.append(stub(condition: { $0.url == url }, response: { _ in
            switch versions {
            case let .success(versions):
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.keyEncodingStrategy = .convertToSnakeCase

                let stuffedVersions: [AvailableUpdate]

                if versions.isEmpty == false {
                    // stuff a bunch of random older and invalid versions in, in random places
                    stuffedVersions = versions + [
                        .init(hasAsset: true, prerelease: true, version: "101.1", build: "1"),
                        .init(hasAsset: true, prerelease: false, version: "101.2", build: "1"),
                        .init(hasAsset: false, prerelease: true, version: "101.3", build: "1"),
                        .init(hasAsset: false, prerelease: false, version: "101.4", build: "1"),
                        .init(hasAsset: true, prerelease: true, version: "101.5", build: "1"),
                        .init(hasAsset: true, prerelease: false, version: "50.1", build: "1"),
                        .init(hasAsset: false, prerelease: true, version: "50.2", build: "1"),
                        .init(hasAsset: false, prerelease: false, version: "50.3", build: "1"),
                        .init(hasAsset: false, prerelease: false, version: "2019.1", build: "100000"),
                        .init(hasAsset: false, prerelease: false, version: "2019.100000", build: "100000"),
                        .init(hasAsset: false, prerelease: false, version: "-1", build: "-1"),
                        .init(hasAsset: false, prerelease: false, version: "", build: ""),
                    ].shuffled()
                } else {
                    stuffedVersions = versions
                }

                return HTTPStubsResponse(
                    data: try! encoder.encode(stuffedVersions),
                    statusCode: 200,
                    headers: [:]
                )
            case let .failure(error):
                return HTTPStubsResponse(error: error)
            }
        }))

        let promise = updater.check(dueToUserInteraction: dueToUserInteraction)
        switch expecting {
        case let .hasUpdate(version):
            XCTAssertEqual(try hang(promise), try! versions.get()[version])
        case let .updateError(expectedError):
            XCTAssertThrowsError(try hang(promise)) { error in
                XCTAssertEqual(error as? Updater.UpdateError, expectedError)
            }
        case let .networkError(code):
            XCTAssertThrowsError(try hang(promise)) { error in
                XCTAssertEqual((error as? URLError)?.code, code)
            }
        }
    }
}

private extension AvailableUpdate {
    init(
        hasAsset: Bool,
        prerelease: Bool,
        version: String,
        build: String
    ) {
        var assets = [Asset]()
        if hasAsset {
            assets.append(.init(
                browserDownloadUrl: URL(string: "https://example.com/downloadUrl")!,
                name: "Asset Name"
            ))
        }

        self.init(
            id: Int.random(in: 0 ..< Int.max),
            htmlUrl: URL(string: "https://example.com/htmlUrl")!,
            tagName: "release/\(version)/\(build)",
            name: "\(version) (\(build))",
            body: "example body",
            prerelease: prerelease,
            assets: assets
        )
    }
}
