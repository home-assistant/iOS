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

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(AboutViewController.closeAboutView(_:)))

        form
            +++ Section() {
                $0.header = HeaderFooterView<HomeAssistantLogoView>(.nibFile(name: "HomeAssistantLogoView", bundle: nil))
            }
            <<< ButtonRow() {
                $0.title = "Acknowledgements"
                $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                    return self.generateAcknowledgements()
                    }, onDismiss: { vc in
                        let _ = vc.navigationController?.popViewController(animated: true)
                })
            }
            +++ Section()
            <<< ButtonRow() {
                $0.title = "Website"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                openURLInBrowser(url: "https://home-assistant.io/")
            })

            <<< ButtonRow() {
                $0.title = "Forums"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                openURLInBrowser(url: "https://community.home-assistant.io/")
            })

            <<< ButtonRow() {
                $0.title = "Chat"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                openURLInBrowser(url: "https://gitter.im/home-assistant/home-assistant")
            })

            <<< ButtonRow() {
                $0.title = "Documentation"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                openURLInBrowser(url: "https://home-assistant.io/ecosystem/ios/")
            })

            <<< ButtonRow() {
                $0.title = "Home Assistant on Twitter"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                self.openInTwitterApp(username: "home_assistant")
            })

            <<< ButtonRow() {
                $0.title = "Home Assistant on Facebook"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                self.openInFacebook(pageId: "292963007723872")
            })

            <<< ButtonRow() {
                $0.title = "GitHub"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                openURLInBrowser(url: "https://github.com/home-assistant/home-assistant-iOS")
            })

            <<< ButtonRow() {
                $0.title = "GitHub Issue Tracker"
            }.cellUpdate { cell, _ in
                cell.textLabel?.textAlignment = .left
                cell.accessoryType = .disclosureIndicator
                cell.editingAccessoryType = cell.accessoryType
                cell.textLabel?.textColor = nil
            }.onCellSelection({ _ in
                openURLInBrowser(url: "https://github.com/home-assistant/home-assistant-iOS/issues")
            })

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */

    func generateAcknowledgements() -> CPDAcknowledgementsViewController {
//        let robbie = CPDContribution.init(name: "Robbie Trencheny", websiteAddress: "https://twitter.com/robbie", role: "Primary iOS developer")
//        robbie.avatarAddress = "https://s.gravatar.com/avatar/04178c46aa6f009adba24b3e7ac64f14"
//        let paulus = CPDContribution.init(name: "Paulus Schousten", websiteAddress: "https://twitter.com/balloob", role: "Home Assistant creator & BDFL")
//        paulus.avatarAddress = "https://s.gravatar.com/avatar/dee932f2cb7ad0af8c5791217a085d35"
//        let contributors = [robbie, paulus]
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

    func closeAboutView(_ sender: UIBarButtonItem) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

class HomeAssistantLogoView: UIView {

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

//    override init(frame: CGRect) {
//        super.init(frame: frame)
//        let imageView = UIImageView(image: UIImage(named: "Logo"))
//        imageView.frame = CGRect(x: 0, y: 0, width: 320, height: 130)
//        imageView.autoresizingMask = .flexibleWidth
//        self.frame = CGRect(x: 0, y: 0, width: 320, height: 130)
//        imageView.contentMode = .scaleAspectFit
//        self.addSubview(imageView)
//        
//        let descriptionLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 250, height: 50))
//        descriptionLabel.textAlignment = .center
//        descriptionLabel.text = "Awaken your home"
//        self.addSubview(descriptionLabel)
//    }
//    
//    required init?(coder aDecoder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
}
