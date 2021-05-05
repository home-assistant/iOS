import Eureka

class HAFormViewController: FormViewController {
    init() {
        if #available(iOS 14, *), UIScreen.main.traitCollection.userInterfaceIdiom == .mac {
            super.init(style: .grouped)
        } else if #available(iOS 13, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.keyboardDismissMode = .interactive
    }

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // don't end editing automatically
    }
}
