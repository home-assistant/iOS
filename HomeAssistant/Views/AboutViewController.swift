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

class AboutViewController: FormViewController {

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L10n.About.title

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(AboutViewController.close(_:)))

        form
            +++ Section {
                var logoHeader = HeaderFooterView<HomeAssistantLogoView>(.nibFile(name: "HomeAssistantLogoView",
                                                                                  bundle: nil))
                logoHeader.onSetupView = { view, _ in
                    view.AppTitle.text = L10n.About.Logo.appTitle
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        view.Version.text = version
                    }
                    view.Tagline.text = L10n.About.Logo.tagline
                }
                $0.header = logoHeader
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
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    let urlStr = "https://itunes.apple.com/app/id1099568401?action=write-review&mt=8"
                    UIApplication.shared.openURL(URL(string: urlStr)!)
                })
            +++ Section()
            <<< ButtonRow {
                $0.title = L10n.About.Website.title
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    openURLStringInBrowser(url: "https://home-assistant.io/")
                })

            <<< ButtonRow {
                $0.title = L10n.About.Forums.title
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    openURLStringInBrowser(url: "https://community.home-assistant.io/")
                })

            <<< ButtonRow {
                $0.title = L10n.About.Chat.title
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    openURLStringInBrowser(url: "https://discord.gg/C7fXPmt")
                })

            <<< ButtonRow {
                $0.title = L10n.About.Documentation.title
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    openURLStringInBrowser(url: "https://home-assistant.io/docs/ecosystem/ios/")
                })

            <<< ButtonRow {
                $0.title = L10n.About.HomeAssistantOnTwitter.title
                if let lang = Locale.current.languageCode {
                    $0.hidden = Condition(booleanLiteral: lang.hasPrefix("zh"))
                }
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    self.openInTwitterApp(username: "home_assistant")
                })

            <<< ButtonRow {
                $0.title = L10n.About.HomeAssistantOnFacebook.title
                if let lang = Locale.current.languageCode {
                    $0.hidden = Condition(booleanLiteral: lang.hasPrefix("zh"))
                }
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    self.openInFacebook(pageId: "292963007723872")
                })

            <<< ButtonRow {
                $0.title = L10n.About.Github.title
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _  in
                    openURLStringInBrowser(url: "https://github.com/home-assistant/home-assistant-iOS")
                })

            <<< ButtonRow {
                $0.title = L10n.About.GithubIssueTracker.title
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                    cell.accessoryType = .disclosureIndicator
                    cell.editingAccessoryType = cell.accessoryType
                    cell.textLabel?.textColor = nil
                }.onCellSelection({ _, _ in
                    openURLStringInBrowser(url: "https://github.com/home-assistant/home-assistant-iOS/issues")
                })
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
                if #available(iOS 10, *) {
                    UIApplication.shared.open(tweetbotURL, options: [:], completionHandler: nil)
                } else {
                    _ = UIApplication.shared.openURL(tweetbotURL)
                }
                return
            }
        }

        /* Twitter app fallback */
        if let twitterURL = URL(string: "twitter:///user?screen_name="+username) {
            if UIApplication.shared.canOpenURL(twitterURL) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(twitterURL, options: [:], completionHandler: nil)
                } else {
                    _ = UIApplication.shared.openURL(twitterURL)
                }
                return
            }
        }

        /* Safari fallback */
        if let webURL = URL(string: "https://twitter.com/"+username) {
            if UIApplication.shared.canOpenURL(webURL) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
                } else {
                    _ = UIApplication.shared.openURL(webURL)
                }
                return
            }
        }
    }

    func openInFacebook(pageId: String) {
        if let facebookURL = URL(string: "fb://page/"+pageId) {
            if UIApplication.shared.canOpenURL(facebookURL) {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(facebookURL, options: [:], completionHandler: nil)
                } else {
                    _ = UIApplication.shared.openURL(facebookURL)
                }
                return
            }
        }
    }

    @objc func close(_ sender: UIBarButtonItem) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

class HomeAssistantLogoView: UIView {

    @IBOutlet weak var AppTitle: UILabel!
    @IBOutlet weak var Tagline: UILabel!
    @IBOutlet weak var Version: UILabel!
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
