@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit
import WebKit

/// The download sheet the frontend opens for a file: the view model a `WKDownload` reports into,
/// the file it leaves behind and the sheet's progress, finished and failed states.
@MainActor
struct DownloadManagerViewModelTests {
    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func render(_ viewModel: DownloadManagerViewModel) {
        guard #available(iOS 17.0, *) else { return }
        let controller = UIHostingController(rootView: DownloadManagerView(viewModel: viewModel))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func deletingWithoutAFileDoesNothing() {
        let viewModel = DownloadManagerViewModel()
        viewModel.deleteFile()
        viewModel.cancelDownload()
        #expect(viewModel.lastURLCreated == nil)
    }

    @Test func deletingRemovesTheDownloadedFile() throws {
        let viewModel = DownloadManagerViewModel()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("download-\(UUID().uuidString).txt")
        try Data("hello".utf8).write(to: url)
        viewModel.lastURLCreated = url

        viewModel.deleteFile()
        #expect(!FileManager.default.fileExists(atPath: url.path))

        // A second delete finds nothing to remove and only logs it.
        viewModel.deleteFile()
    }

    @Test func aDownloadReportsItsFileAndFinishes() async throws {
        let viewModel = DownloadManagerViewModel()
        let webView = WKWebView(frame: .zero)
        let url = try #require(URL(string: "data:text/plain;base64,aGVsbG8gd29ybGQ="))

        let download = await webView.startDownload(using: URLRequest(url: url))
        download.delegate = viewModel

        let expectation1 = await waitUntil { viewModel.finished || viewModel.failed }
        #expect(expectation1)
        #expect(viewModel.finished != viewModel.failed)
        if viewModel.finished {
            #expect(!viewModel.fileName.isEmpty)
            #expect(viewModel.lastURLCreated != nil)
        } else {
            #expect(!viewModel.errorMessage.isEmpty)
        }
        viewModel.cancelDownload()
        viewModel.deleteFile()
    }

    @Test func rendersTheProgressFinishedAndFailedStates() throws {
        let inProgress = DownloadManagerViewModel()
        inProgress.fileName = "report.pdf"
        inProgress.progress = "1 MB"
        render(inProgress)

        let finished = DownloadManagerViewModel()
        finished.fileName = "report.pdf"
        finished.finished = true
        finished.lastURLCreated = FileManager.default.temporaryDirectory.appendingPathComponent("missing.pdf")
        render(finished)

        let finishedWithoutFile = DownloadManagerViewModel()
        finishedWithoutFile.finished = true
        render(finishedWithoutFile)

        let failed = DownloadManagerViewModel()
        failed.failed = true
        failed.errorMessage = "Download failed"
        render(failed)
    }
}
