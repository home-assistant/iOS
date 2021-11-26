import Eureka
import Foundation
import HAKit
import Shared

class TemplateEditViewController: HAFormViewController, RowControllerType {
    var onDismissCallback: ((UIViewController) -> Void)?
    var saveHandler: (Server, String) -> Void

    private var server: Server {
        didSet {
            templateSection?.server = server
        }
    }

    private let initialValue: String
    private var templateSection: TemplateSection?

    init(
        server: Server,
        initial: String,
        saveHandler: @escaping (Server, String) -> Void
    ) {
        self.server = server
        self.saveHandler = saveHandler
        self.initialValue = initial
        super.init()

        if #available(iOS 13, *) {
            isModalInPresentation = true
        }

        self.title = L10n.Settings.TemplateEdit.title
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        _ = templateSection?.inputRow.cell.textView.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save)),
        ]

        let section = TemplateSection(
            header: nil,
            footer: nil,
            server: server,
            initializeInput: {
                $0.value = initialValue
                $0.placeholder = "{{ now() }}"
            }, initializeSection: { _ in
            }
        )

        section <<< ServerSelectRow {
            $0.value = .server(server)
            $0.onChange { [weak self] row in
                if case let .server(server) = row.value {
                    self?.server = server
                }
            }
        }

        form +++ section
        templateSection = section
    }

    @objc private func cancel() {
        onDismissCallback?(self)
    }

    @objc private func save() {
        if let section = templateSection {
            saveHandler(server, section.inputRow.value ?? "")
        }
        onDismissCallback?(self)
    }
}
