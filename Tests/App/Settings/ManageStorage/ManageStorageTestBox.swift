/// A mutable box so a test can observe what an escaping closure was handed.
final class ManageStorageTestBox<Value>: @unchecked Sendable {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}
