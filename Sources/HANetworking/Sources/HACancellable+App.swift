import HAKit

public class HABlockCancellable: HACancellable {
    private var handler: (() -> Void)?

    public init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    public func cancel() {
        handler?()
        handler = nil
    }
}

public class HANoopCancellable: HACancellable {
    public init() {}
    public func cancel() {}
}
