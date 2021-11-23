import Eureka
import PromiseKit
import Shared

class ServerSelectViewController: HAFormViewController, ServerObserver {
    let result: Promise<AccountRowValue>
    private let resultSeal: Resolver<AccountRowValue>

    enum ServerSelectError: Error, CancellableError {
        case cancelled

        var isCancelled: Bool {
            switch self {
            case .cancelled: return true
            }
        }
    }

    var prompt: String? {
        didSet {
            setupForm()
        }
    }

    var allowAll: Bool = false {
        didSet {
            setupForm()
        }
    }

    override init() {
        (self.result, self.resultSeal) = Promise<AccountRowValue>.pending()
        super.init()

        title = NSLocalizedString("Select Server", comment: "")
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel(_:)))
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupForm()
        Current.servers.add(observer: self)
    }

    @objc private func cancel(_ sender: UIBarButtonItem) {
        resultSeal.reject(ServerSelectError.cancelled)
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if #available(iOS 15, *), let parent = parent as? UINavigationController, parent.viewControllers == [self] {
            with(parent.sheetPresentationController) {
                $0?.detents = [.medium()]
            }
        }
    }

    func serversDidChange(_ serverManager: ServerManager) {
        setupForm()
    }

    private func setupForm() {
        form.removeAll()

        if let prompt = prompt, !prompt.isEmpty {
            form +++ InfoLabelRow {
                $0.title = prompt
            }
        }

        var rows = [AccountRowValue]()

        if allowAll {
            rows.append(.all)
        }

        rows.append(contentsOf: Current.servers.all.map { .server($0) })

        form +++ Section(rows.map { value in
            HomeAssistantAccountRow {
                $0.value = value
                $0.onCellSelection { [resultSeal] cell, row in
                    resultSeal.fulfill(value)
                }
            }
        })
    }
}
