import Foundation
import Shared
import SwiftUI

final class CameraCardViewModel: ObservableObject {
    @Published var image: Image?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var snapshotDate: Date?

    private let serverId: String
    private let entityId: String
    private let imageExpirationDuration: Measurement<UnitDuration> = .init(value: 10, unit: .seconds)
    private var refreshTimer: DispatchSourceTimer?
    private var isViewVisible = false

    init(serverId: String, entityId: String) {
        self.serverId = serverId
        self.entityId = entityId
    }

    deinit {
        stopRefreshTimer()
    }

    func viewDidAppear() {
        isViewVisible = true
        loadImageURL()
        startRefreshTimer()
    }

    func viewDidDisappear() {
        isViewVisible = false
        stopRefreshTimer()
    }

    func loadImageURL() {
        // Check if image is still valid
        if let snapshotDate {
            let elapsedTime = Current.date().timeIntervalSince(snapshotDate)
            let expirationInterval = imageExpirationDuration.converted(to: .seconds).value

            if elapsedTime < expirationInterval {
                // Image is still fresh, don't reload
                return
            }
        }

        setLoading(true)
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            setError(L10n.Camera.serverNotFound)
            return
        }
        Current.api(for: server)?.getCameraSnapshot(cameraEntityID: entityId).pipe { [weak self] result in
            switch result {
            case let .fulfilled(image):
                self?.setImage(image)
            case let .rejected(error):
                let errorMessage = L10n.Camera.snapshotFailed
                Current.Log
                    .error("\(errorMessage) for \(String(describing: self?.entityId)): \(error.localizedDescription)")
                self?.setError(errorMessage)
            }
        }
    }

    func forceReload() {
        // Clear the snapshot date to force a reload
        snapshotDate = nil
        loadImageURL()
    }

    private func startRefreshTimer() {
        stopRefreshTimer()
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self, self.isViewVisible else { return }

            if let snapshotDate = self.snapshotDate {
                let elapsedTime = Current.date().timeIntervalSince(snapshotDate)
                let expirationInterval = self.imageExpirationDuration.converted(to: .seconds).value

                if elapsedTime >= expirationInterval {
                    self.loadImageURL()
                }
            }
        }
        timer.resume()
        refreshTimer = timer
    }

    private func stopRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    private func setImage(_ uiImage: UIImage) {
        DispatchQueue.main.async { [weak self] in
            self?.image = Image(uiImage: uiImage)
            self?.snapshotDate = Current.date()
            self?.errorMessage = nil
            self?.isLoading = false
        }
    }

    private func setError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.image = nil
            self?.snapshotDate = nil
            self?.isLoading = false
        }
    }

    private func setLoading(_ loading: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = loading
        }
    }
}
