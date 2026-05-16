import Foundation

struct ShoppingItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var quantity: String
    var isChecked: Bool = false
    var imageURL: String?
    
    // Helper to generate a random image for demo purposes if no URL is provided
    static func randomPlaceholderImage(for name: String) -> String {
        return "https://loremflickr.com/320/240/\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "food")"
    }
}

struct Friend: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var code: String
}
