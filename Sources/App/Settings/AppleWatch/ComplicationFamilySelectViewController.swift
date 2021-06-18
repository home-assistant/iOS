import Eureka
import Foundation
import Shared

class ComplicationFamilySelectViewController: HAFormViewController, RowControllerType {
    let allowMultiple: Bool
    let currentFamilies: Set<ComplicationGroupMember>

    init(allowMultiple: Bool, currentFamilies: Set<ComplicationGroupMember>) {
        self.allowMultiple = allowMultiple
        self.currentFamilies = currentFamilies
        super.init()
    }

    var onDismissCallback: ((UIViewController) -> Void)?

    @objc private func cancel(_ sender: UIBarButtonItem) {
        onDismissCallback?(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L10n.Watch.Configurator.New.title

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:))),
        ]

        if !allowMultiple, !currentFamilies.isEmpty {
            form +++ InfoLabelRow {
                $0.title = L10n.Watch.Configurator.New.multipleComplicationInfo
            }
        }

        setupForm()
    }

    private func setupForm() {
        form.append(contentsOf: ComplicationGroup.allCases.sorted().map { group in
            let section = Section(header: group.name, footer: group.description)
            section.append(contentsOf: group.members.sorted().map { family in
                ButtonRow {
                    $0.title = family.shortName
                    $0.cellStyle = .subtitle

                    if !allowMultiple, currentFamilies.contains(family) {
                        $0.disabled = true
                    }

                    $0.cellUpdate { cell, row in
                        if #available(iOS 13, *) {
                            cell.detailTextLabel?.textColor = row.isDisabled ? .tertiaryLabel : .secondaryLabel
                            cell.textLabel?.textColor = row.isDisabled ? .secondaryLabel : .label
                        } else {
                            cell.detailTextLabel?.textColor = row.isDisabled ? .lightGray : .darkGray
                            cell.textLabel?.textColor = row.isDisabled ? .darkGray : .black
                        }
                        cell.detailTextLabel?.numberOfLines = 0
                        cell.detailTextLabel?.lineBreakMode = .byWordWrapping
                        cell.detailTextLabel?.text = family.description

                        if row.isDisabled {
                            cell.accessibilityTraits.insert(.notEnabled)
                        } else {
                            cell.accessibilityTraits.remove(.notEnabled)
                        }
                    }

                    $0.presentationMode = .show(controllerProvider: .callback { [allowMultiple] in
                        let complication = WatchComplication()
                        complication.Family = family

                        if !allowMultiple {
                            // if the user hasn't upgraded to watchOS 7 yet, we want to preserve our migration behavior
                            // so any watchOS 6-created complications have a predicable globally-unique identifier
                            complication.identifier = family.rawValue
                        }

                        return ComplicationEditViewController(config: complication)
                    }, onDismiss: { [weak self] vc in
                        guard let self = self, let vc = vc as? ComplicationEditViewController else { return }

                        if vc.config.realm == nil {
                            // not saved
                            self.navigationController?.popViewController(animated: true)
                        } else {
                            // saved
                            self.onDismissCallback?(self)
                        }
                    })
                }
            })
            return section
        })
    }
}
