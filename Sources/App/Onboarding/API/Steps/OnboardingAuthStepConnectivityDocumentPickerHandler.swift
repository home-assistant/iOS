//
//  OnboardingDocumentPicker.swift
//  HomeAssistant
//
//  Created by Bruno Pantaleão on 28/05/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import CoreServices
import PromiseKit

final class OnboardingAuthStepConnectivityDocumentPickerHandler: NSObject, UIDocumentPickerDelegate {
    let promise: Promise<Data?>
    private let seal: Resolver<Data?>

    override init() {
        (promise, seal) = Promise<Data?>.pending()
        super.init()
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        seal.reject(PMKError.cancelled)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            seal.fulfill(nil)
            return
        }

        let didStartSecurityScoped = url.startAccessingSecurityScopedResource()
        let coordinator = NSFileCoordinator()

        var error: NSError?
        coordinator.coordinate(readingItemAt: url, error: &error) { url in
            seal.resolve(Swift.Result { try Data(contentsOf: url) })
        }

        if let error = error {
            // if it was successful, it would have resolved the result
            seal.reject(error)
        }

        if didStartSecurityScoped {
            url.stopAccessingSecurityScopedResource()
        }
    }
}
