import Lottie
import PromiseKit
import Shared
import UIKit

class ConnectInstanceViewController: UIViewController {
    enum ConnectionRow: Equatable, Hashable, CaseIterable {
        case connectionStatus
        case authenticated
        case integrationCreated
        case cloudStatus
        case encrypted
        case sensorsConfigured

        var title: String {
            switch self {
            case .connectionStatus: return L10n.Onboarding.Final.State.connection
            case .authenticated: return L10n.Onboarding.Final.State.authenticated
            case .integrationCreated: return L10n.Onboarding.Final.State.integration
            case .cloudStatus: return L10n.Onboarding.Final.State.cloud
            case .encrypted: return L10n.Onboarding.Final.State.encrypted
            case .sensorsConfigured: return L10n.Onboarding.Final.State.sensors
            }
        }
    }

    private var overallAnimation = AnimationView()
    private var animationViews: [ConnectionRow: AnimationView] = {
        var views = [ConnectionRow: AnimationView]()
        for key in ConnectionRow.allCases {
            views[key] = with(AnimationView()) {
                $0.loopMode = .loop
                $0.contentMode = .scaleAspectFill
                $0.animation = Animation.named("loader-success-failed")
            }
        }
        return views
    }()

    private var wantedAnimationStates: [ConnectionRow: AnimationState] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Current.style.onboardingBackground
        navigationItem.hidesBackButton = true

        let (_, stackView, equalSpacers) = UIView.contentStackView(in: view, scrolling: true)

        stackView.addArrangedSubview(with(UILabel()) {
            $0.text = L10n.Onboarding.Final.title
            Current.style.onboardingTitle($0)
        })

        stackView.addArrangedSubview(with(overallAnimation) {
            $0.loopMode = .loop
            $0.contentMode = .scaleAspectFill
            $0.animation = Animation.named("home")
            $0.play()

            NSLayoutConstraint.activate([
                $0.widthAnchor.constraint(equalTo: $0.heightAnchor),
                $0.widthAnchor.constraint(equalToConstant: 128.0),
            ])
        })

        for row in ConnectionRow.allCases {
            let view = with(UIStackView()) {
                $0.axis = .horizontal
                $0.alignment = .fill

                $0.addArrangedSubview(with(UILabel()) {
                    $0.text = row.title
                    $0.font = .preferredFont(forTextStyle: .callout)
                    $0.textColor = Current.style.onboardingLabel
                    $0.numberOfLines = 0
                    $0.setContentHuggingPriority(.defaultLow, for: .horizontal)
                })

                $0.addArrangedSubview(with(animationViews[row]!) {
                    NSLayoutConstraint.activate([
                        $0.widthAnchor.constraint(equalTo: $0.heightAnchor),
                        $0.widthAnchor.constraint(equalToConstant: 32.0),
                    ])
                })
            }

            stackView.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stackView.layoutMarginsGuide.widthAnchor)
                .isActive = true
        }

        stackView.addArrangedSubview(equalSpacers.next())

        for row in ConnectionRow.allCases {
            switch row {
            case .connectionStatus, .authenticated:
                setAnimationStatus(row, state: .success, waitingForCompletion: false)
            default:
                setAnimationStatus(row, state: .loading, waitingForCompletion: false)
            }
        }

        Connect().done { [overallAnimation] in
            Current.Log.verbose("Done with setup, continuing!")

            overallAnimation.loopMode = .playOnce
        }.then {
            after(seconds: 6.0)
        }.done {
            Current.onboardingObservation.complete()

            if let navVC = self.navigationController as? OnboardingNavigationViewController {
                Current.Log.verbose("Dismissing from permissions")
                navVC.dismiss()
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

    private func setAnimationStatus(_ row: ConnectionRow, state: AnimationState, waitingForCompletion: Bool = true) {
        let animationView = animationViews[row]!

        switch state {
        case .failed, .success:
            animationView.loopMode = .playOnce
            wantedAnimationStates[row] = state
            if !waitingForCompletion {
                finalizeAnimation(for: row)
            }
        case .loading:
            animationView.play(fromFrame: state.startFrame, toFrame: state.endFrame, loopMode: .loop) { [weak self] _ in
                self?.finalizeAnimation(for: row)
            }
        }
    }

    private func finalizeAnimation(for row: ConnectionRow) {
        guard let wantedState = wantedAnimationStates[row], wantedState != .loading else { return }

        animationViews[row]!.play(
            fromFrame: wantedState.startFrame,
            toFrame: wantedState.endFrame,
            loopMode: .playOnce,
            completion: nil
        )
        wantedAnimationStates[row] = nil
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
        }.get { [self] _, regResponse in
            setAnimationStatus(.integrationCreated, state: .success)

            let cloudAvailable = (regResponse.CloudhookURL != nil || regResponse.RemoteUIURL != nil)
            let cloudState: AnimationState = cloudAvailable ? .success : .failed
            setAnimationStatus(.cloudStatus, state: cloudState)

            if cloudAvailable {
                Current.settingsStore.connectionInfo?.useCloud = true
            }

            let encryptState: AnimationState = regResponse.WebhookSecret != nil ? .success : .failed
            setAnimationStatus(.encrypted, state: encryptState)
        }.map { api, _ in
            api
        }.then { api in
            when(fulfilled: [
                api.GetConfig().asVoid(),
                Current.modelManager.fetch(),
                api.RegisterSensors().asVoid(),
            ]).asVoid()
        }.get { [self] _ in
            setAnimationStatus(.sensorsConfigured, state: .success)

            NotificationCenter.default.post(
                name: HomeAssistantAPI.didConnectNotification,
                object: nil,
                userInfo: nil
            )

            Current.apiConnection.connect()
        }
    }
}
