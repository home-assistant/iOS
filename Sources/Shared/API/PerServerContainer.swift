import Foundation

public class PerServerContainer<ObjectType>: ServerObserver {
    public struct Value {
        public var object: ObjectType
        public var destructor: Destructor?

        public init(_ object: ObjectType, destructor: Destructor? = nil) {
            self.object = object
            self.destructor = destructor
        }
    }

    public typealias Constructor = (Server) -> Value
    public typealias Destructor = (Identifier<Server>, ObjectType) -> Void

    private var lazy: Bool
    public var constructor: Constructor {
        didSet {
            destruct(from: backing, to: [:])
            createAll()
        }
    }

    private var backing = [Identifier<Server>: Value]() {
        willSet {
            destruct(from: backing, to: newValue)
        }
    }

    public init(lazy: Bool = false, constructor: @escaping Constructor) {
        self.constructor = constructor
        self.lazy = lazy
        Current.servers.add(observer: self)
        createAll()
    }

    deinit {
        destruct(from: backing, to: [:])
    }

    public subscript(_ server: Server) -> ObjectType {
        if let value = backing[server.identifier] {
            return value.object
        } else {
            let value = constructor(server)
            backing[server.identifier] = value
            return value.object
        }
    }

    private func destruct(from: [Identifier<Server>: Value], to: [Identifier<Server>: Value]) {
        for (key, value) in from where to[key] == nil {
            value.destructor?(key, value.object)
        }
    }

    private func createAll() {
        guard !lazy else { return }
        for server in Current.servers.all {
            backing[server.identifier] = constructor(server)
        }
    }

    public func serversDidChange(_ serverManager: ServerManager) {
        let existing = Set(backing.keys)
        let servers = Current.servers.all

        let deleted = existing.subtracting(servers.map(\.identifier))
        let needed = servers.filter { !existing.contains($0.identifier) }

        backing = deleted.reduce(into: backing) { result, identifier in
            result[identifier] = nil
        }

        if !lazy {
            backing = needed.reduce(into: backing) { result, server in
                result[server.identifier] = constructor(server)
            }
        }
    }
}
