import Eureka

class HAFormViewController: FormViewController {
    enum Style {
        case automatic
        case grouped
        case insetGrouped
    }

    init(style: Style = .automatic) {
        switch style {
        case .automatic:
            if #available(iOS 14, *), UIScreen.main.traitCollection.userInterfaceIdiom == .mac {
                super.init(style: .grouped)
            } else if #available(iOS 13, *) {
                super.init(style: .insetGrouped)
            } else {
                super.init(style: .grouped)
            }
        case .grouped:
            super.init(style: .grouped)
        case .insetGrouped:
            if #available(iOS 13, *) {
                super.init(style: .insetGrouped)
            } else {
                super.init(style: .grouped)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
