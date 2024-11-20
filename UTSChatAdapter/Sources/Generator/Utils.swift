import Foundation

typealias JSON = [String: Any]

extension StringProtocol {
    func firstLowercased() -> String { prefix(1).lowercased() + dropFirst() }
    func firstUppercased() -> String { prefix(1).uppercased() + dropFirst() }
}

extension JSON {
    func sortedByKey() -> [Element] {
        sorted { element1, element2 in
            element1.key > element2.key
        }
    }
}
