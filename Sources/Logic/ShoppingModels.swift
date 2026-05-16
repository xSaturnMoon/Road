import Foundation

struct ShoppingItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var quantity: String
    var isChecked: Bool = false
}

struct Friend: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var code: String
}
