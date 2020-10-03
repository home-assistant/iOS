//
//  OnboardingViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Shared
import Eureka
import Lottie
import Reachability
import RealmSwift

class WelcomeViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var animationView: AnimationView!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var wifiWarningLabel: UILabel!

    private var loggedOutView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        let reachability = (self.navigationController as? OnboardingNavigationViewController)?.reachability
        self.wifiWarningLabel.isHidden = reachability?.connection == .wifi

        if let navVC = self.navigationController as? OnboardingNavigationViewController {
            navVC.styleButton(self.continueButton)
        }

        self.animationView.animation = Animation.named("ha-loading")
        self.animationView.loopMode = .playOnce
        self.animationView.play(toMarker: "Circles Formed")

        if prefs.bool(forKey: "onboardingShouldShowMigrationMessage") {
            setupLoggedOutView()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let reachability = (self.navigationController as? OnboardingNavigationViewController)?.reachability

        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)),
                                               name: .reachabilityChanged, object: reachability)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        let reachability = (self.navigationController as? OnboardingNavigationViewController)?.reachability
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueType = StoryboardSegue.Onboarding(segue) else { return }
        if segueType == .manuallyConnectInstance, let vc = segue.destination as? ManualSetupViewController {
            vc.notOnWifi = false
        }
    }

    @IBAction func continueButton(_ sender: UIButton) {
        if self.wifiWarningLabel.isHidden {
            self.perform(segue: StoryboardSegue.Onboarding.discoverInstances, sender: nil)
        } else {
            self.perform(segue: StoryboardSegue.Onboarding.manuallyConnectInstance, sender: nil)
        }
    }

    @objc func reachabilityChanged(_ note: Notification) {
        guard let reachability = note.object as? Reachability else {
            Current.Log.warning("Couldn't cast notification object as Reachability")
            return
        }

        Current.Log.verbose("Reachability changed to \(reachability.connection.description)")
        self.wifiWarningLabel.isHidden = (reachability.connection == .wifi)
    }
}

// logged out from app store migration handling
extension WelcomeViewController {
    // swiftlint:disable:next function_body_length
    private func setupLoggedOutView() {
        let scrollView = with(UIScrollView()) {
            $0.contentInsetAdjustmentBehavior = .always
            $0.alwaysBounceVertical = true
            $0.backgroundColor = view.backgroundColor
        }

        let container = with(UIStackView()) {
            $0.axis = .vertical
            $0.spacing = 24.0
            $0.directionalLayoutMargins = .init(top: 32, leading: 32, bottom: 32, trailing: 32)
            $0.isLayoutMarginsRelativeArrangement = true
        }
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)

        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor)
        ])

        func textView() -> UITextView {
            with(UITextView()) {
                $0.textContainer.lineFragmentPadding = 0
                $0.textContainerInset = .zero
                $0.contentInset = .zero
                $0.backgroundColor = .clear
                $0.adjustsFontForContentSizeCategory = true
                $0.textColor = .white
                $0.isScrollEnabled = false
                $0.isEditable = false
            }
        }

        container.addArrangedSubview(with(UILabel()) {
            $0.font = UIFont.preferredFont(forTextStyle: .title1)
            $0.adjustsFontForContentSizeCategory = true
            $0.numberOfLines = 0
            $0.textColor = .white
            $0.text = L10n.Onboarding.LoggedOutFromMove.title
        })

        container.addArrangedSubview(with(textView()) {
            $0.font = UIFont.preferredFont(forTextStyle: .body)
            $0.textColor = .white
            $0.text = L10n.Onboarding.LoggedOutFromMove.body
        })

        container.addArrangedSubview(with(UIButton(type: .system)) {
            $0.contentHorizontalAlignment = .leading
            $0.setAttributedTitle(NSAttributedString(string: L10n.Onboarding.LoggedOutFromMove.learnMore, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.white,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]), for: .normal)
            $0.addTarget(self, action: #selector(learnMoreAboutMove), for: .touchUpInside)
        })

        container.addArrangedSubview(with(UIView()) {
            $0.setContentHuggingPriority(.defaultLow, for: .vertical)
        })

        let showDuplicateWarning: Bool = {
            guard let values = try? Realm.storeDirectoryURL.resourceValues(forKeys: [.creationDateKey]) else {
                Current.Log.info("not showing duplicate warning - can't read creation date")
                return false
            }

            guard let creationDate = values.creationDate else {
                Current.Log.info("not showing duplicate warning - no creation date")
                return false
            }

            // 2020.1 was released on 6/12/2020 and it was the first version to send device_id to integration
            guard let testDate = Calendar.current.date(from: .init(year: 2020, month: 6, day: 12)) else {
                Current.Log.info("not showing duplicate warning - calendars are broken")
                return false
            }

            return creationDate < testDate
        }()

        if showDuplicateWarning {
            Current.Log.info("showing duplicate warning")
            container.addArrangedSubview(with(textView()) {
                $0.font = UIFont.preferredFont(forTextStyle: .body)
                $0.text = L10n.Onboarding.LoggedOutFromMove.duplicateWarning
                $0.backgroundColor = UIColor(red: 255.0/255.0, green: 255.0/255.0, blue: 219.0/255.0, alpha: 1.0)
                $0.textColor = .black
                $0.textContainerInset = .init(top: 8, left: 8, bottom: 8, right: 8)
            })
        } else {
            Current.Log.info("not showing duplicate warning")
        }

        container.addArrangedSubview(with(UIButton(type: .system)) {
            $0.setTitle(L10n.Onboarding.LoggedOutFromMove.continue, for: .normal)
            $0.setTitleColor(view.backgroundColor, for: .normal)
            $0.setBackgroundImage(.init(size: CGSize(width: 1, height: 1), color: .white), for: .normal)
            $0.contentEdgeInsets = .init(top: 16, left: 8, bottom: 16, right: 8)
            $0.titleLabel?.font = .preferredFont(forTextStyle: .callout)
            $0.titleLabel?.baselineAdjustment = .alignCenters
            $0.titleLabel?.adjustsFontSizeToFitWidth = true
            $0.titleLabel?.adjustsFontForContentSizeCategory = true
            $0.layer.cornerRadius = 12.0
            $0.layer.masksToBounds = true

            $0.addTarget(self, action: #selector(continueFromLoggedOut), for: .touchUpInside)
        })

        loggedOutView = scrollView
    }

    @objc private func learnMoreAboutMove() {
        openURLInBrowser(URL(string: "https://companion.home-assistant.io/app/ios/about-the-move")!, self)
    }

    @objc private func dismissLearnMore() {
        dismiss(animated: true, completion: nil)
    }

    @objc private func continueFromLoggedOut() {
        prefs.removeObject(forKey: "onboardingShouldShowMigrationMessage")
        loggedOutView?.removeFromSuperview()
    }

}
