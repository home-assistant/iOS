import CoreLocation
import Eureka
import Foundation
import PromiseKit
import Shared

final class CustomHeaderConfigurator: HAFormViewController, TypedRowControllerType {
    typealias RowValue = CustomHeaderConfigurator
    var row: RowOf<RowValue>!
    var onDismissCallback: ((UIViewController) -> Void)?
    let server: Server

    var customHeader = CustomHeaderStruct()

    private(set) var shouldSave: Bool = false

    init(customHeader: CustomHeaderStruct?, server: Server, row: RowOf<RowValue>) {
        self.server = server
        self.row = row

        if let customHeader = customHeader {
            self.customHeader = customHeader
        }

        super.init()

        self.title = "Custom Header"
        if let key = customHeader?.key{
            self.title = key
        }

        self.isModalInPresentation = true

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save)),
        ]
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc private func save() {
        let key = (form.rowBy(tag: RowTag.key.rawValue) as? TextRow)?.value
        let value = (form.rowBy(tag: RowTag.value.rawValue) as? TextRow)?.value
        let useInternal = (form.rowBy(tag: RowTag.useInternal.rawValue) as? SwitchRow)?.value
        let useExternal = (form.rowBy(tag: RowTag.useExternal.rawValue) as? SwitchRow)?.value

        Current.Log.verbose("Go back hit, check for validation")

        if form.validate().count == 0 {
            Current.Log.verbose("Category form is valid, calling dismiss callback!")
            shouldSave = true

            if let key = key {
                customHeader.key = key
            }

            if let value = value {
                customHeader.value = value
            }

            if let useInternal = useInternal {
                customHeader.useInternal = useInternal
            }

            if let useExternal = useExternal {
                customHeader.useExternal = useExternal
            }

            onDismissCallback?(self)

        }
    }

    fileprivate enum RowTag: String {
        case key
        case value
        case useInternal
        case useExternal
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        TextRow.defaultCellUpdate = { cell, row in
            if !row.isValid {
                cell.textLabel?.textColor = .red
            }
        }

        form
            +++ Section(
            header: "HEADER",
            footer: "Insert the key part and the value part separatly")

            <<< TextRow(RowTag.key.rawValue) {
                $0.title = "Key"
                $0.add(rule: RuleRequired())
                $0.value = customHeader.key
                $0.placeholder = { () -> String? in
                    return "Enter key here"
                }()
            }

            <<< TextRow(RowTag.value.rawValue) {
                $0.title = "Value"
                $0.add(rule: RuleRequired())
                $0.value = customHeader.value
                $0.placeholder = { () -> String? in
                    return "Enter value here"
                }()
            }

            +++ Section(
            footer: "Select for which URL the header should be used")

            <<< SwitchRow {
                $0.title = "Use for internal URL"
                $0.tag = RowTag.useInternal.rawValue
                $0.value = customHeader.useInternal
            }

            <<< SwitchRow {
                $0.title = "Use for external URL"
                $0.tag = RowTag.useExternal.rawValue
                $0.value = customHeader.useExternal
            }
    }
}

