import Lottie
import Shared
import UIKit

class ConnectionErrorViewController: UIViewController {
    @IBOutlet var animationView: AnimationView!
    @IBOutlet var moreInfoButton: UIButton!
    @IBOutlet var errorLabel: UILabel!
    @IBOutlet var goBackButton: UIButton!

    var error: Error!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let navVC = navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(moreInfoButton)
            navVC.styleButton(goBackButton)
        }

        animationView.animation = Animation.named("error")
        animationView.loopMode = .playOnce
        animationView.contentMode = .scaleAspectFill
        animationView.play()

        errorLabel.text = error.localizedDescription

        if let error = error as? ConnectionTestResult {
            if error.kind == .sslExpired || error.kind == .sslUntrusted {
                let text = L10n.Onboarding.ConnectionTestResult.SslContainer.description(error.localizedDescription)
                errorLabel.text = text
            }
        } else {
            moreInfoButton.isHidden = true
        }
    }

    /*
     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         // Get the new view controller using segue.destination.
         // Pass the selected object to the new view controller.
     }
     */

    @IBAction func moreInfoTapped(_ sender: UIButton) {
        guard let error = self.error as? ConnectionTestResult else { return }
        openURLInBrowser(error.DocumentationURL, self)
    }

    @IBAction func startOverTapped(_ sender: Any) {
        let controller = StoryboardScene.Onboarding.welcome.instantiate()
        show(controller, sender: self)
    }
}
