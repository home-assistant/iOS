import Eureka
import Lottie
import Reachability
import RealmSwift
import Shared
import UIKit

class WelcomeViewController: UIViewController, UITextViewDelegate {
    @IBOutlet var animationView: AnimationView!
    @IBOutlet var continueButton: UIButton!
    @IBOutlet var wifiWarningLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        let reachability = (navigationController as? OnboardingNavigationViewController)?.reachability
        wifiWarningLabel.isHidden = reachability?.connection == .wifi

        if let navVC = navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(continueButton)
        }

        animationView.animation = Animation.named("ha-loading")
        animationView.loopMode = .playOnce
        animationView.play(toMarker: "Circles Formed")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let reachability = (navigationController as? OnboardingNavigationViewController)?.reachability

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityChanged(_:)),
            name: .reachabilityChanged,
            object: reachability
        )
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        let reachability = (navigationController as? OnboardingNavigationViewController)?.reachability
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }

    @IBAction func continueButton(_ sender: UIButton) {
        if wifiWarningLabel.isHidden {
            show(StoryboardScene.Onboarding.discoverInstances.instantiate(), sender: self)
        } else {
            show(StoryboardScene.Onboarding.manualSetup.instantiate(), sender: self)
        }
    }

    @objc func reachabilityChanged(_ note: Notification) {
        guard let reachability = note.object as? Reachability else {
            Current.Log.warning("Couldn't cast notification object as Reachability")
            return
        }

        Current.Log.verbose("Reachability changed to \(reachability.connection.description)")
        wifiWarningLabel.isHidden = (reachability.connection == .wifi)
    }
}
