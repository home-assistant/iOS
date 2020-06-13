//
//  AboutViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 1/6/17.
//  Copyright © 2017 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import SafariServices
import CPDAcknowledgements
import Shared

class AboutViewController: FormViewController {

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.bounces = false

        self.title = L10n.About.title

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(AboutViewController.close(_:)))

        ButtonRow.defaultCellUpdate = { cell, row in
            cell.textLabel?.textAlignment = .left
            cell.accessoryType = .disclosureIndicator
            cell.editingAccessoryType = cell.accessoryType
            cell.textLabel?.textColor = nil
        }

        var hideBecauseChina = Condition(booleanLiteral: false)

        if let lang = Locale.current.languageCode, lang.hasPrefix("zh") {
            hideBecauseChina = Condition(booleanLiteral: true)
        }

        form
            +++ Section {
                var logoHeader = HeaderFooterView<HomeAssistantLogoView>(.nibFile(name: "HomeAssistantLogoView",
                                                                                  bundle: nil))
                logoHeader.onSetupView = { view, _ in
                    view.AppTitle.text = L10n.About.Logo.appTitle
                    view.Version.text = prefs.string(forKey: "lastInstalledVersion")
                    view.Tagline.text = L10n.About.Logo.tagline
                    view.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                     action: #selector(self.tapAbout(_:))))
                }

                $0.header = logoHeader
                $0.tag = "logoView"
            }

             +++ ButtonRow {
                   $0.title = L10n.About.Donate.patreon
               }.onCellSelection { _, _  in
                   let urlStr = "https://patreon.com/robbiet480/"
                   openURLInBrowser(URL(string: urlStr)!, self)
               }

            <<< ButtonRow {
                    $0.title = L10n.About.Beta.title
                    $0.disabled = Condition(booleanLiteral: Current.appConfiguration == .Beta)
                }.onCellSelection { _, _  in
                    let urlStr = "https://home-assistant.io/ios/beta/"
                    // We want to open this in Safari so the TestFlight redirect works.
                    UIApplication.shared.open(URL(string: urlStr)!, options: [:], completionHandler: nil)
                }

            <<< ButtonRow {
                $0.title = L10n.About.Acknowledgements.title
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    return self.generateAcknowledgements()
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
                })
            }

            <<< ButtonRow {
                    $0.title = L10n.About.Review.title
                }.onCellSelection { _, _  in
                    let urlStr = "https://itunes.apple.com/app/id1099568401?action=write-review&mt=8"
                    UIApplication.shared.open(URL(string: urlStr)!, options: [:], completionHandler: nil)
                }

            <<< ButtonRow {
                $0.title = L10n.About.HelpLocalize.title
                }.onCellSelection { _, _  in
                    let urlStr = "https://developers.home-assistant.io/docs/en/internationalization_translation.html"
                    openURLInBrowser(URL(string: urlStr)!, self)
            }

            +++ ButtonRow {
                    $0.title = L10n.About.Website.title
                }.onCellSelection { _, _  in
                    openURLInBrowser(URL(string: "https://www.home-assistant.io/")!, self)
                }

            <<< ButtonRow {
                    $0.title = L10n.About.Forums.title
                }.onCellSelection { _, _  in
                    openURLInBrowser(URL(string: "https://community.home-assistant.io/")!, self)
                }

            <<< ButtonRow {
                    $0.title = L10n.About.Chat.title
                }.onCellSelection { _, _  in
                    openURLInBrowser(URL(string: "https://discord.gg/C7fXPmt")!, self)
                }

            <<< ButtonRow {
                    $0.title = L10n.About.Documentation.title
                }.onCellSelection { _, _  in
                    openURLInBrowser(URL(string: "https://www.home-assistant.io/docs/ecosystem/ios/")!, self)
                }

            <<< ButtonRow {
                    $0.title = L10n.About.HomeAssistantOnTwitter.title
                    $0.hidden = hideBecauseChina
                }.onCellSelection { _, _  in
                    self.openInTwitterApp(username: "home_assistant")
                }

            <<< ButtonRow {
                    $0.title = L10n.About.HomeAssistantOnFacebook.title
                    $0.hidden = hideBecauseChina
                }.onCellSelection { _, _  in
                    self.openInFacebook(pageId: "292963007723872")
                }

            <<< ButtonRow {
                    $0.title = L10n.About.Github.title
                }.onCellSelection { _, _  in
                    openURLInBrowser(URL(string: "https://github.com/home-assistant/home-assistant-iOS")!, self)
                }

            <<< ButtonRow {
                    $0.title = L10n.About.GithubIssueTracker.title
                }.onCellSelection { _, _ in
                    openURLInBrowser(URL(string: "https://github.com/home-assistant/home-assistant-iOS/issues")!, self)
                }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func generateAcknowledgements() -> CPDAcknowledgementsViewController {
        return CPDAcknowledgementsViewController.init(style: nil, acknowledgements: nil, contributions: nil)
    }

    func openInTwitterApp(username: String) {
        /* Tweetbot app precedence */
        if let tweetbotURL = URL(string: "tweetbot:///user_profile/"+username) {
            if UIApplication.shared.canOpenURL(tweetbotURL) {
                UIApplication.shared.open(tweetbotURL, options: [:], completionHandler: nil)
                return
            }
        }

        /* Twitter app fallback */
        if let twitterURL = URL(string: "twitter:///user?screen_name="+username) {
            if UIApplication.shared.canOpenURL(twitterURL) {
                UIApplication.shared.open(twitterURL, options: [:], completionHandler: nil)
                return
            }
        }

        /* Safari fallback */
        if let webURL = URL(string: "https://twitter.com/"+username) {
            if UIApplication.shared.canOpenURL(webURL) {
                UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                return
            }
        }
    }

    func openInFacebook(pageId: String) {
        if let facebookURL = URL(string: "fb://page/"+pageId) {
            if UIApplication.shared.canOpenURL(facebookURL) {
                UIApplication.shared.open(facebookURL, options: [:], completionHandler: nil)
                return
            }
        }
    }

    @objc func close(_ sender: UIBarButtonItem) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }

    @objc func tapAbout(_ sender: Any) {
        let alert = UIAlertController(title: L10n.About.EasterEgg.title,
                                      message: L10n.About.EasterEgg.message,
                                      preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "<3",
                                      style: UIAlertAction.Style.default,
                                      handler: nil))
        self.present(alert, animated: true, completion: nil)
        if let popOver = alert.popoverPresentationController,
            let sect = self.form.sectionBy(tag: "logoView"),
                let logoView = sect.header?.viewForSection(sect, type: .header) {
            popOver.sourceView = logoView
        }
    }
}

class HomeAssistantLogoView: UIView {

    @IBOutlet weak var AppTitle: UILabel!
    @IBOutlet weak var Tagline: UILabel!
    @IBOutlet weak var Version: UILabel!
    @IBOutlet weak var Image: UIImageView!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
