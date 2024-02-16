import CoreLocation
import Eureka
import Foundation
import PromiseKit
import Shared

final class ConnectionCustomHeaderViewController: HAFormViewController, TypedRowControllerType {
    typealias RowValue = ConnectionCustomHeaderViewController
    var row: RowOf<RowValue>!
    var onDismissCallback: ((UIViewController) -> Void)?
    let server: Server
    var localCustomHeaders: [CustomHeaderStruct] = []

    init(server: Server, row: RowOf<RowValue>) {
        self.server = server
        self.row = row

        super.init()

        self.title = "Custom Headers"

        if let customHeaders = server.info.connection.customHeaders {
            localCustomHeaders = customHeaders
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
        server.update { info in
            if let section = form.sectionBy(tag: RowTag.customHeaders.rawValue) as? MultivaluedSection {
                let tags = section.allRows
                    .compactMap{$0 as? ButtonRowWithPresent<CustomHeaderConfigurator>}
                    .compactMap(\.tag)
                    .filter { !$0.isEmpty }

                func tagsContaintsKey(key: String) -> Bool {
                    tags.contains(where: {$0 == key})
                }

                info.connection.customHeaders = localCustomHeaders.filter{tagsContaintsKey(key: $0.key)}
            }
        }

        onDismissCallback?(self)
    }

    fileprivate enum RowTag: String {
        case customHeaders
    }

    override func viewDidLoad() {
        super.viewDidLoad()


        form +++ MultivaluedSection(
            multivaluedOptions: [.Insert, .Delete],
            footer: "Here you can add custom headers that will be added to each request. Headers with the same key will be ignored and not saved"
        ) { section in
            section.tag = ConnectionCustomHeaderViewController.RowTag.customHeaders.rawValue
            section.multivaluedRowToInsertAt = { [weak self] _ -> ButtonRowWithPresent<CustomHeaderConfigurator> in
                self?.getHeaderRow(nil) ?? .init()
            }
            section.addButtonProvider = { _ in
                ButtonRow {
                    $0.title = L10n.addButtonLabel
                    $0.cellStyle = .value1
                    $0.tag = "add_header"
                }.cellUpdate { cell, _ in
                    cell.textLabel?.textAlignment = .left
                }
            }

            for customHeader in localCustomHeaders {
                section <<< getHeaderRow(customHeader)
            }
        }
    }

    func getSubtitle(useInternal: Bool, useExternal: Bool) -> String {
        if useInternal  && useExternal {
            return "Used for internal and external URL"
        } else if useInternal {
            return "Used for internl URL"
        } else if useExternal {
            return "Used for external URL"
        } else {
            return "Unused"
        }
    }

    func getHeaderRow(_ inputHeader: CustomHeaderStruct?) -> ButtonRowWithPresent<CustomHeaderConfigurator> {
        var customHeader = inputHeader
        var title = ""
        var useInternal = false
        var useExternal = false

        if let passedHeader = inputHeader {
            title = passedHeader.key
            useInternal = passedHeader.useInternal
            useExternal = passedHeader.useExternal
        }

        return ButtonRowWithPresent<CustomHeaderConfigurator> { row in
            row.cellStyle = .subtitle
            row.title = title
            row.tag = title
            row.displayValueFor = { _ in
                self.getSubtitle(useInternal: useInternal, useExternal: useExternal)
            }
            row.presentationMode = .show(controllerProvider: .callback(builder: { [server] in
                CustomHeaderConfigurator(customHeader: customHeader, server: server, row: row)
            }), onDismiss: { [weak self] vc in
                _ = vc.navigationController?.popViewController(animated: true)

                if let vc = vc as? CustomHeaderConfigurator {
                    if vc.shouldSave == false {
                        Current.Log.verbose("Not saving customHeader and returning early!")
                        return
                    }

                    customHeader = vc.customHeader
                    vc.row.tag = vc.customHeader.key
                    vc.row.title = vc.customHeader.key
                    vc.row.displayValueFor = { _ in
                        self?.getSubtitle(useInternal: useInternal, useExternal: useExternal)
                    }
                    vc.row.updateCell()

                    if !(self?.localCustomHeaders.contains(where: {$0.key == vc.customHeader.key}) ?? true) {
                        self?.localCustomHeaders.append(vc.customHeader)
                    } else {
                        if let index = self?.localCustomHeaders.firstIndex(where: {$0.key == vc.customHeader.key}){
                            self?.localCustomHeaders[index] = vc.customHeader
                        }
                    }
                }
            })
        }

    }
}





