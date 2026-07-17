public extension HAAPIRequest where Response == [HAAPIEntityState] {
    static func getStates() -> Self {
        .init(command: "get_states")
    }
}
