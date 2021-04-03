import Lottie
import PromiseKit
import Shared
import UIKit

class ConnectInstanceViewController: UIViewController {
    var instance: DiscoveredHomeAssistant!
    var connectionInfo: ConnectionInfo!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var overallProgress: AnimationView!
    @IBOutlet var connectionStatus: AnimationView!
    @IBOutlet var authenticated: AnimationView!
    @IBOutlet var integrationCreated: AnimationView!
    @IBOutlet var cloudStatus: AnimationView!
    @IBOutlet var encrypted: AnimationView!
    @IBOutlet var sensorsConfigured: AnimationView!

    private var wantedAnimationStates: [AnimationView: AnimationState] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = L10n.Onboarding.Connect.title(instance.LocationName)

        configureAnimation(connectionStatus, .success)
        configureAnimation(authenticated, .success)

        overallProgress.loopMode = .loop
        overallProgress.contentMode = .scaleAspectFill
        overallProgress.animation = Animation.named("home")
        overallProgress.play()

        let completedSteps: [AnimationView] = [connectionStatus, authenticated]
        for animationView in completedSteps {
            animationView.loopMode = .playOnce
            animationView.contentMode = .scaleAspectFill
            animationView.animation = Animation.named("loader-success-failed")
            animationView.play(fromFrame: AnimationState.success.startFrame, toFrame: AnimationState.success.endFrame)
        }

        let pendingViews: [AnimationView] = [integrationCreated, cloudStatus, encrypted, sensorsConfigured]
        for aView in pendingViews {
            configureAnimation(aView)
        }

        Connect().done {
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
            let alert = UIAlertController(
                title: L10n.errorLabel,
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func configureAnimation(_ animationView: AnimationView, _ state: AnimationState = .loading) {
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFill
        animationView.animation = Animation.named("loader-success-failed")
        setAnimationStatus(animationView, state: state)
    }

    private func setAnimationStatus(_ animationView: AnimationView, state: AnimationState) {
        switch state {
        case .failed, .success:
            animationView.loopMode = .playOnce
            wantedAnimationStates[animationView] = state
        case .loading:
            animationView.play(fromFrame: state.startFrame, toFrame: state.endFrame, loopMode: .loop) { _ in
                self.finalizeAnimationView(animationView)
            }
        }
    }

    private func finalizeAnimationView(_ animationView: AnimationView) {
        guard let wantedState = wantedAnimationStates[animationView], wantedState != .loading else { return }

        animationView.play(
            fromFrame: wantedState.startFrame,
            toFrame: wantedState.endFrame,
            loopMode: .playOnce,
            completion: nil
        )
        wantedAnimationStates[animationView] = nil
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

        return Current.api.then(on: nil) { api in
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
            when(fulfilled: [
                api.GetConfig().asVoid(),
                Current.modelManager.fetch(),
                api.RegisterSensors().asVoid(),
            ]).asVoid()
        }.map { _ in
            NotificationCenter.default.post(
                name: HomeAssistantAPI.didConnectNotification,
                object: nil,
                userInfo: nil
            )

            self.setAnimationStatus(self.sensorsConfigured, state: .success)
        }
    }
}
