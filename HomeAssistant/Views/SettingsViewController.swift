//
//  SettingsViewController.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/20/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import UIKit
import Eureka
import Shared

class SettingsViewController: FormViewController {

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        let aboutButton = UIBarButtonItem(title: L10n.Settings.NavigationBar.AboutButton.title,
                                          style: .plain, target: self,
                                          action: #selector(SettingsViewController.openAbout(_:)))

        self.navigationItem.setLeftBarButton(aboutButton, animated: true)

        let closeSelector = #selector(OldSettingsViewController.closeSettings(_:))
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                         action: closeSelector)

        self.navigationItem.setRightBarButton(doneButton, animated: true)

        form +++ Section(L10n.Settings.StatusSection.header) {
            $0.tag = "status"
        }
        <<< LabelRow("locationName") {
            $0.title = L10n.Settings.StatusSection.LocationNameRow.title
            $0.value = L10n.Settings.StatusSection.LocationNameRow.placeholder
            if let locationName = prefs.string(forKey: "location_name") {
                $0.value = locationName
            }
        }
        <<< LabelRow("version") {
            $0.title = L10n.Settings.StatusSection.VersionRow.title
            $0.value = L10n.Settings.StatusSection.VersionRow.placeholder
            if let version = prefs.string(forKey: "version") {
                $0.value = version
            }
        }

        +++ Section(L10n.Settings.NavigationBar.title)
        <<< ButtonRow("onboardTest") {
            $0.title = "Onboard"
            $0.presentationMode = .presentModally(controllerProvider: .storyBoard(storyboardId: "navController",
                                                                                  storyboardName: "Onboarding",
                                                                                  bundle: Bundle.main), onDismiss: nil)
        }
        <<< ButtonRow("generalSettings") {
            $0.title = L10n.Settings.GeneralSettingsButton.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "general"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow {
            $0.title = "Connection"
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                return ConnectionSettingsViewController()
            }, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow("locationSettings") {
            $0.title = L10n.Settings.DetailsSection.LocationSettingsRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "location"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow("notificationSettings") {
            $0.title = L10n.Settings.DetailsSection.NotificationSettingsRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "notifications"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        +++ Section(L10n.Settings.DetailsSection.Integrations.header)
        <<< ButtonRow {
            $0.tag = "actions"
            $0.title = L10n.SettingsDetails.Actions.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "actions"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow {
            $0.tag = "watchSettings"
            $0.title = L10n.Settings.DetailsSection.WatchRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "watchSettings"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        <<< ButtonRow {
            $0.hidden = Condition(booleanLiteral: UIDevice.current.systemVersion == "12")
            $0.tag = "siriShortcuts"
            $0.title = L10n.Settings.DetailsSection.SiriShortcutsRow.title
            $0.presentationMode = .show(controllerProvider: ControllerProvider.callback {
                let view = SettingsDetailViewController()
                view.detailGroup = "siri"
                return view
                }, onDismiss: { vc in
                    _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        +++ ButtonRow("eventLog") {
            $0.title = L10n.Settings.EventLog.title
            let controllerProvider = ControllerProvider.storyBoard(storyboardId: "clientEventsList",
                                                                   storyboardName: "ClientEvents",
                                                                   bundle: Bundle.main)
            $0.presentationMode = .show(controllerProvider: controllerProvider, onDismiss: { vc in
                _ = vc.navigationController?.popViewController(animated: true)
            })
        }

        +++ Section {
            $0.tag = "reset"
            // $0.hidden = Condition(booleanLiteral: !self.configured)
        }
        <<< ButtonRow("resetApp") {
                $0.title = L10n.Settings.ResetSection.ResetRow.title
            }.cellUpdate { cell, _ in
                cell.textLabel?.textColor = .red
            }.onCellSelection { cell, row in
                let alert = UIAlertController(title: L10n.Settings.ResetSection.ResetAlert.title,
                                              message: L10n.Settings.ResetSection.ResetAlert.message,
                                              preferredStyle: UIAlertController.Style.alert)

                alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))

                alert.addAction(UIAlertAction(title: L10n.Settings.ResetSection.ResetAlert.title,
                                              style: .destructive, handler: { (_) in
                                                row.hidden = true
                                                row.evaluateHidden()
                                                self.ResetApp()
                }))

                self.present(alert, animated: true, completion: nil)
                alert.popoverPresentationController?.sourceView = cell.formViewController()?.view
        }
    }

    @objc func openAbout(_ sender: UIButton) {
        let aboutView = AboutViewController()

        let navController = UINavigationController(rootViewController: aboutView)
        self.show(navController, sender: nil)
    }

    @objc func closeSettings(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    func ResetApp() {
        Current.Log.verbose("Resetting app!")
        resetStores()
        setDefaults()
        let bundleId = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: bundleId)
        UserDefaults.standard.synchronize()
        prefs.removePersistentDomain(forName: bundleId)
        prefs.synchronize()
        let urlRow: URLRow = self.form.rowBy(tag: "baseURL")!
        urlRow.value = nil
        urlRow.updateCell()
        let statusSection: Section = self.form.sectionBy(tag: "status")!
        statusSection.hidden = true
        statusSection.evaluateHidden()
        let detailsSection: Section = self.form.sectionBy(tag: "details")!
        detailsSection.hidden = true
        detailsSection.evaluateHidden()
        self.tableView.reloadData()
    }

}
