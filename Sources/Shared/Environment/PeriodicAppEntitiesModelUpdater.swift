import Foundation
import HAKit

public protocol PeriodicAppEntitiesModelUpdaterProtocol {
    func setup()
    func stop()
    func updateAppEntities()
}

final class PeriodicAppEntitiesModelUpdater: PeriodicAppEntitiesModelUpdaterProtocol {
    static var shared = PeriodicAppEntitiesModelUpdater()

    private var requestTokens: [HACancellable?] = []
    private var timer: Timer?

    func setup() {
        startUpdateTimer()
    }

    func stop() {
        cancelOnGoingRequests()
        timer?.invalidate()
    }

    func updateAppEntities() {
        cancelOnGoingRequests()
        Current.servers.all.forEach { server in
            guard server.info.connection.activeURL() != nil else { return }
            let requestToken = Current.api(for: server)?.connection.send(
                HATypedRequest<[HAEntity]>.fetchStates(),
                completion: { result in
                    switch result {
                    case let .success(entities):
                        Current.appEntitiesModel().updateModel(Set(entities), server: server)
                    case let .failure(error):
                        Current.Log.error("Failed to fetch states: \(error)")
                    }
                }
            )
            requestTokens.append(requestToken)
        }
    }

    private func cancelOnGoingRequests() {
        requestTokens.forEach { $0?.cancel() }
        requestTokens = []
    }

    // Start timer that updates app entities every 5 minutes
    private func startUpdateTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.updateAppEntities()
        }
    }
}
