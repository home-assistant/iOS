import Eureka
import Shared

extension Eureka.Condition {
    static var isCatalyst: Condition { .init(booleanLiteral: Current.isCatalyst) }
    static var isNotCatalyst: Condition { .init(booleanLiteral: !Current.isCatalyst) }
}
