import Foundation
import Shared

final class MockWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    private(set) var cleanCacheCallCount = 0
    private(set) var cleanFrontendAssetCacheIfNeededCallCount = 0
    private(set) var lastDataTypes: Set<String>?
    private var pendingCompletion: (() -> Void)?
    private var pendingFrontendAssetCacheCompletion: ((Bool) -> Void)?

    func cleanCache(dataTypes: Set<String>, completion: (() -> Void)?) {
        cleanCacheCallCount += 1
        lastDataTypes = dataTypes
        pendingCompletion = completion
    }

    func cleanFrontendAssetCacheIfNeeded(completion: ((Bool) -> Void)?) {
        cleanFrontendAssetCacheIfNeededCallCount += 1
        pendingFrontendAssetCacheCompletion = completion
    }

    func invokePendingCompletion() {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?()
    }

    func invokePendingFrontendAssetCacheCompletion(didClean: Bool) {
        let completion = pendingFrontendAssetCacheCompletion
        pendingFrontendAssetCacheCompletion = nil
        completion?(didClean)
    }
}
