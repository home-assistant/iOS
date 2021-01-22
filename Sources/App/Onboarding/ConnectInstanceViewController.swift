//
//  ConnectInstanceViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/21/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Lottie
import Shared
import PromiseKit

class ConnectInstanceViewController: UIViewController {

    var instance: DiscoveredHomeAssistant!
    var connectionInfo: ConnectionInfo!
    var tokenManager: TokenManager!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var overallProgress: AnimationView!
    @IBOutlet weak var connectionStatus: AnimationView!
    @IBOutlet weak var authenticated: AnimationView!
    @IBOutlet weak var integrationCreated: AnimationView!
    @IBOutlet weak var cloudStatus: AnimationView!
    @IBOutlet weak var encrypted: AnimationView!
    @IBOutlet weak var sensorsConfigured: AnimationView!

    private var wantedAnimationStates: [AnimationView: AnimationState] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        self.titleLabel.text = L10n.Onboarding.Connect.title(self.instance.LocationName)

        self.configureAnimation(connectionStatus, .success)
        self.configureAnimation(authenticated, .success)

        self.overallProgress.loopMode = .loop
        self.overallProgress.contentMode = .scaleAspectFill
        self.overallProgress.animation = Animation.named("home")
        self.overallProgress.play()

        let completedSteps: [AnimationView] = [connectionStatus, authenticated]
        for animationView in completedSteps {
            animationView.loopMode = .playOnce
            animationView.contentMode = .scaleAspectFill
            animationView.animation = Animation.named("loader-success-failed")
            animationView.play(fromFrame: AnimationState.success.startFrame, toFrame: AnimationState.success.endFrame)
        }

        let pendingViews: [AnimationView] = [integrationCreated, cloudStatus, encrypted, sensorsConfigured]
        for aView in pendingViews {
            self.configureAnimation(aView)
        }

        self.Connect().done {
            Current.Log.verbose("Done with setup, continuing!")

            self.overallProgress.loopMode = .playOnce

            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                Current.onboardingObservation.complete()

                if let navVC = self.navigationController as? OnboardingNavigationViewController {
                    Current.Log.verbose("Dismissing from permissions")
                    navVC.dismiss()
                }
            }
        }.catch { error in
            let alert = UIAlertController(title: L10n.errorLabel, message: error.localizedDescription,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func configureAnimation(_ animationView: AnimationView, _ state: AnimationState = .loading) {
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFill
        animationView.animation = Animation.named("loader-success-failed")
        self.setAnimationStatus(animationView, state: state)
    }

    private func setAnimationStatus(_ animationView: AnimationView, state: AnimationState) {
        switch state {
        case .failed, .success:
            animationView.loopMode = .playOnce
            self.wantedAnimationStates[animationView] = state
        case .loading:
            animationView.play(fromFrame: state.startFrame, toFrame: state.endFrame, loopMode: .loop) { _ in
                self.finalizeAnimationView(animationView)
            }
        }
    }

    private func finalizeAnimationView(_ animationView: AnimationView) {
        guard let wantedState = self.wantedAnimationStates[animationView], wantedState != .loading else { return }

        animationView.play(fromFrame: wantedState.startFrame, toFrame: wantedState.endFrame, loopMode: .playOnce,
                           completion: nil)
        self.wantedAnimationStates[animationView] = nil
    }

    private enum AnimationState {
        case loading // frames 0-324
        case success // frames 325-400
        case failed // frames 700-820

        var startFrame: AnimationProgressTime {
            switch self {
            case .loading:
                return 0
            case .success:
                return 325
            case .failed:
                return 700
            }
        }

        var endFrame: AnimationProgressTime {
            switch self {
            case .loading:
                return 324
            case .success:
                return 400
            case .failed:
                return 820
            }
        }
    }

    enum ConnectionError: Error {
        case noAuthenticatedAPI
    }

    public func Connect() -> Promise<Void> {
        Current.resetAPI()

        return Current.api.then { api in
            api.Register().map { (api, $0) }
        }.map { api, regResponse -> HomeAssistantAPI in
            self.setAnimationStatus(self.integrationCreated, state: .success)

            let cloudAvailable = (regResponse.CloudhookURL != nil || regResponse.RemoteUIURL != nil)
            let cloudState: AnimationState = cloudAvailable ? .success : .failed
            self.setAnimationStatus(self.cloudStatus, state: cloudState)

            if cloudAvailable {
                Current.settingsStore.connectionInfo?.useCloud = true
            }

            let encryptState: AnimationState = regResponse.WebhookSecret != nil ? .success : .failed
            self.setAnimationStatus(self.encrypted, state: encryptState)

            return api
        }.then { api in
            return when(fulfilled: [
                api.GetConfig().asVoid(),
                Current.modelManager.fetch(),
                api.RegisterSensors().asVoid()
            ]).asVoid()
        }.map { _ in
            NotificationCenter.default.post(name: HomeAssistantAPI.didConnectNotification,
                                            object: nil, userInfo: nil)

            self.setAnimationStatus(self.sensorsConfigured, state: .success)
        }
    }
}
