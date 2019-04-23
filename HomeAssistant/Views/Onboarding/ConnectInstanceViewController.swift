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

class ConnectInstanceViewController: UIViewController {

    var instance: DiscoveryInfoResponse!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var overallProgress: AnimationView!
    @IBOutlet weak var connectionStatus: AnimationView!
    @IBOutlet weak var integrationCreated: AnimationView!
    @IBOutlet weak var cloudStatus: AnimationView!
    @IBOutlet weak var encrypted: AnimationView!
    @IBOutlet weak var sensorsConfigured: AnimationView!

    var animationViews: [AnimationView] = []

    private var wantedAnimationStates: [AnimationView: AnimationState] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.becomeFirstResponder()

        self.animationViews.append(contentsOf: [connectionStatus, integrationCreated, cloudStatus, encrypted,
                                                sensorsConfigured])

        self.titleLabel.text = "Connecting to \(self.instance.LocationName)"

        self.overallProgress.loopMode = .loop
        self.overallProgress.contentMode = .scaleAspectFill
        self.overallProgress.animation = Animation.named("home")
        self.overallProgress.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 12.5) {
            self.overallProgress.loopMode = .playOnce
        }

        for (idx, aView) in animationViews.enumerated() {
            self.configureAnimation(aView)

            let time = 2.5 * Double(idx)
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                if idx % 2 == 0 {
                    self.setAnimationStatus(aView, state: .success)
                } else {
                    self.setAnimationStatus(aView, state: .failed)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            self.performSegue(withIdentifier: "permissions", sender: nil)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }

    private func configureAnimation(_ animationView: AnimationView) {
        animationView.loopMode = .loop
        animationView.contentMode = .scaleAspectFill
        animationView.animation = Animation.named("loader-success-failed")
        self.setAnimationStatus(animationView, state: .loading)
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

    override var canBecomeFirstResponder: Bool {
        return true
    }

    override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        self.resetForDemo()
    }

    private func resetForDemo() {
        for (idx, aView) in animationViews.enumerated() {
            self.setAnimationStatus(aView, state: .loading)

            let time = 2.5 * Double(idx)
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                if idx % 2 == 0 {
                    self.setAnimationStatus(aView, state: .success)
                } else {
                    self.setAnimationStatus(aView, state: .failed)
                }
            }
        }
    }
}
