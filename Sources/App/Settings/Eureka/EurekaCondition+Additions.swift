import Eureka
import Shared

extension Eureka.Condition {
    static var isDebug: Condition { .init(booleanLiteral: Current.isDebug) }
    static var isNotDebug: Condition { .init(booleanLiteral: !Current.isDebug) }
    static var isCatalyst: Condition { .init(booleanLiteral: Current.isCatalyst) }
    static var isNotCatalyst: Condition { .init(booleanLiteral: !Current.isCatalyst) }
}
