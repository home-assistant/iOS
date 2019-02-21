//
//  NotificationCategoryConfigurator.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/28/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import Eureka
import UserNotifications
import RealmSwift
import Shared
import Iconic
import CleanroomLogger

class NotificationCategoryConfigurator: FormViewController, TypedRowControllerType {
    var row: RowOf<ButtonRow>!
    /// A closure to be called when the controller disappears.
    public var onDismissCallback: ((UIViewController) -> Void)?

    var settings: UNNotificationSettings?
    var category: NotificationCategory = NotificationCategory()
    var newCategory: Bool = true
    var allActions: [String: NotificationAction] = [:]
    var shouldSave: Bool = false

    // Notifications are allowed a max of 4 actions if using Alerts and 2 if using Banner
    private var maxActionsForCategory = 4
    private let defaultMultivalueOptions: MultivaluedOptions = [.Reorder, .Insert, .Delete]
    private var addButtonRow: ButtonRow = ButtonRow()
    private let realm = Current.realm()

    convenience init(category: NotificationCategory?, settings: UNNotificationSettings?) {
        self.init()
        self.settings = settings
        if let category = category {
            self.category = category
            self.newCategory = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let cancelSelector = #selector(NotificationCategoryConfigurator.cancel)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self,
                                                                 action: cancelSelector)

        let saveSelector = #selector(NotificationCategoryConfigurator.save)

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self,
                                                                 action: saveSelector)

        let infoButton = UIButton(type: .infoLight)

        infoButton.addTarget(self, action: #selector(NotificationCategoryConfigurator.getInfoAction),
                             for: .touchUpInside)

        let infoButtonView = UIBarButtonItem(customView: infoButton)

        let previewButton = UIBarButtonItem(withIcon: .eyeIcon, size: CGSize(width: 25, height: 25), target: self,
                                            action: #selector(NotificationCategoryConfigurator.preview))

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)

        self.setToolbarItems([infoButtonView, flexibleSpace, previewButton], animated: false)

        self.navigationController?.setToolbarHidden(false, animated: false)

        self.title = L10n.NotificationsConfigurator.Category.NavigationBar.title

        if newCategory == false {
            self.title = category.Name
        }

        TextRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        TextAreaRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.placeholderLabel?.textColor = .red
            }
        }

        NotificationIdentifierRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        let existingActions = realm.objects(NotificationAction.self)
//        let existingActions = objs.sorted(byKeyPath: "Order")

        var settingsFooter = L10n.NotificationsConfigurator.Settings.footer

        if self.newCategory {
            settingsFooter = L10n.NotificationsConfigurator.Settings.Footer.idSet
        }

        self.form
        +++ Section(header: L10n.NotificationsConfigurator.Settings.header, footer: settingsFooter)

        <<< TextRow {
            $0.tag = "name"
            $0.title = L10n.NotificationsConfigurator.Category.Rows.Name.title
            $0.add(rule: RuleRequired())
            if !newCategory {
                $0.value = self.category.Name
            }
        }.onChange { row in
            if let value = row.value {
                self.category.Name = value
            }
        }

        <<< NotificationIdentifierRow {
            $0.tag = "identifier"
            $0.title = L10n.NotificationsConfigurator.identifier
            if !newCategory {
                $0.value = self.category.Identifier
            }
        }.onChange { row in
            if let value = row.value {
                self.category.Identifier = value
            }
        }

        if #available(iOS 11.0, *) {
        self.form
            +++ Section(header: L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.header,
                        footer: L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.footer)
            <<< TextAreaRow {
                $0.tag = "hiddenPreviewsBodyPlaceholder"
                $0.placeholder = L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.default
                if !newCategory && self.category.HiddenPreviewsBodyPlaceholder != "" {
                    $0.value = self.category.HiddenPreviewsBodyPlaceholder
                } else {
                    $0.value = L10n.NotificationsConfigurator.Category.Rows.HiddenPreviewPlaceholder.default
                }
            }.onChange { row in
                if let value = row.value {
                    self.category.HiddenPreviewsBodyPlaceholder = value
                }
            }
        }

        if #available(iOS 12.0, *) {
            self.form
                +++ Section(header: L10n.NotificationsConfigurator.Category.Rows.CategorySummary.header,
                            footer: L10n.NotificationsConfigurator.Category.Rows.CategorySummary.footer)
                <<< TextAreaRow {
                    $0.tag = "categorySummaryFormat"
                    if !newCategory && self.category.CategorySummaryFormat != "" {
                        $0.value = self.category.CategorySummaryFormat
                    } else {
                        $0.value = L10n.NotificationsConfigurator.Category.Rows.CategorySummary.default
                    }
                }.onChange { row in
                    if let value = row.value {
                        self.category.CategorySummaryFormat = value
                    }
                }
        }

        // Default footer if we can't get Notification Settings for some reason
        var footer = L10n.NotificationsConfigurator.Category.Rows.Actions.Footer.default

        if let settings = self.settings {
            if settings.alertStyle == .alert {
                footer = L10n.NotificationsConfigurator.Category.Rows.Actions.Footer.Style.alert
            } else if settings.alertStyle == .banner {
                maxActionsForCategory = 2
                footer = L10n.NotificationsConfigurator.Category.Rows.Actions.Footer.Style.banner
            }
        }

        self.form
            +++ MultivaluedSection(multivaluedOptions: defaultMultivalueOptions,
                                   header: L10n.NotificationsConfigurator.Category.Rows.Actions.header,
                                   footer: footer) { section in
                    section.multivaluedRowToInsertAt = { index in

                        if index >= self.maxActionsForCategory - 1 {
                            section.multivaluedOptions = [.Reorder, .Delete]

                            self.addButtonRow.hidden = true

                            DispatchQueue.main.async { // I'm not sure why this is necessary
                                self.addButtonRow.evaluateHidden()
                            }
                        }

                        return self.getActionRow(nil)
                    }

                    section.addButtonProvider = { section in
                        self.addButtonRow = ButtonRow {
                            $0.title = L10n.NotificationsConfigurator.Category.Rows.Actions.AddRow.title
                            $0.cellStyle = .value1
                        }.cellUpdate { cell, _ in
                            cell.textLabel?.textAlignment = .left
                        }
                        return self.addButtonRow
                    }

                    for action in existingActions {
                        section <<< self.getActionRow(action)
                    }
                }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func rowsHaveBeenRemoved(_ rows: [BaseRow], at indexes: [IndexPath]) {
        super.rowsHaveBeenRemoved(rows, at: indexes)
        if let index = indexes.first?.section, let section = form.allSections[index] as? MultivaluedSection {
            if section.count < maxActionsForCategory {
                section.multivaluedOptions = self.defaultMultivalueOptions
                self.addButtonRow.hidden = false // or could
                self.addButtonRow.evaluateHidden()
            }
        }
    }

    func getActionRow(_ action: NotificationAction?) -> ButtonRowWithPresent<NotificationActionConfigurator> {
        var identifier = "new_action_"+UUID().uuidString
        var title = L10n.NotificationsConfigurator.NewAction.title

        if let action = action {
            identifier = action.Identifier
            title = action.Title
        }

        return ButtonRowWithPresent<NotificationActionConfigurator> {
            $0.tag = identifier
            $0.title = title

            $0.presentationMode = PresentationMode.show(controllerProvider: ControllerProvider.callback {
                return NotificationActionConfigurator(action: action)
            }, onDismiss: { vc in
                vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? NotificationActionConfigurator {
                    vc.row.title = vc.action.Title
                    vc.row.updateCell()
                    Log.verbose?.message("action \(vc.action)")

                    // swiftlint:disable:next force_try
                    try! self.realm.write {
                        self.realm.add(vc.action, update: true)
                    }

                    self.category.Actions.append(vc.action)
                }

            })
        }
    }

    @objc
    func getInfoAction(_ sender: Any) {
        Log.verbose?.message("getInfoAction hit, open docs page!")
    }

    @objc
    func save(_ sender: Any) {
        Log.verbose?.message("Go back hit, check for validation")

        Log.verbose?.message("Validate result \(self.form.validate())")
        if self.form.validate().count == 0 {
            Log.verbose?.message("Category form is valid, calling dismiss callback!")

            self.shouldSave = true

            onDismissCallback?(self)
        }
    }

    @objc
    func cancel(_ sender: Any) {
        Log.verbose?.message("Cancel hit, calling dismiss")

        self.shouldSave = false

        onDismissCallback?(self)
    }

    @objc
    func preview(_ sender: Any) {
        Log.verbose?.message("Preview hit")

        let content = UNMutableNotificationContent()
        content.title = "Test notification"
        content.body = "This is a test notification for the \(self.category.Name) notification category"
        content.sound = .default
        content.categoryIdentifier = self.category.Identifier

        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: self.category.Identifier,
                                                                     content: content, trigger: nil))
    }

}
