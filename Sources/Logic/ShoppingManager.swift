import Foundation
import Combine

class ShoppingManager: ObservableObject {
    static let shared = ShoppingManager()
    
    @Published var items: [ShoppingItem] = []
    @Published var friends: [Friend] = []
    @Published var myCode: String = ""
    @Published var observingFriend: Friend?
    @Published var observingItems: [ShoppingItem] = []
    
    private let itemsKey = "bloom_shopping_items"
    private let friendsKey = "bloom_shopping_friends"
    private let codeKey = "bloom_shopping_my_code"
    
    private var syncTimer: Timer?
    
    init() {
        loadLocalData()
        setupSync()
    }
    
    func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.items = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: friendsKey),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            self.friends = decoded
        }
        
        if let savedCode = UserDefaults.standard.string(forKey: codeKey) {
            self.myCode = savedCode
        } else {
            let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
            let newCode = String((0..<6).compactMap { _ in chars.randomElement() })
            self.myCode = newCode
            UserDefaults.standard.set(newCode, forKey: codeKey)
        }
    }
    
    func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }
        syncToNetwork()
    }
    
    func saveFriends() {
        if let encoded = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(encoded, forKey: friendsKey)
        }
    }
    
    func addItem(name: String, quantity: String) {
        let newItem = ShoppingItem(name: name, quantity: quantity)
        items.insert(newItem, at: 0)
        saveItems()
    }
    
    func toggleItem(_ item: ShoppingItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isChecked.toggle()
            saveItems()
        }
    }
    
    func deleteItem(_ item: ShoppingItem) {
        items.removeAll(where: { $0.id == item.id })
        saveItems()
    }
    
    func clearChecked() {
        items.removeAll(where: { $0.isChecked })
        saveItems()
    }
    
    func clearAll() {
        items.removeAll()
        saveItems()
    }
    
    // MARK: - Sync Logic (ntfy.sh)
    
    func syncToNetwork() {
        guard !myCode.isEmpty else { return }
        
        let url = URL(string: "https://ntfy.sh/bloom_shopping_\(myCode)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let payload = ["items": items]
        if let jsonData = try? JSONEncoder().encode(payload) {
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request).resume()
        }
    }
    
    func setupSync() {
        // Poll for updates every 10 seconds for simplicity (ntfy.sh supports WebSockets but URLSession WebSocket is more complex to implement quickly)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pollMySync()
            self?.pollFriendSync()
        }
    }
    
    private func pollMySync() {
        // Optional: Sync back from network if other devices updated it
    }
    
    private func pollFriendSync() {
        guard let friend = observingFriend else { return }
        
        let url = URL(string: "https://ntfy.sh/bloom_shopping_\(friend.code)/json?poll=1")!
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let jsonString = String(data: data, encoding: .utf8) else { return }
            
            let lines = jsonString.components(separatedBy: "\n").filter { !$0.isEmpty }
            if let lastLine = lines.last,
               let lastData = lastLine.data(using: .utf8),
               let ntfyMessage = try? JSONSerialization.jsonObject(with: lastData) as? [String: Any],
               let messageString = ntfyMessage["message"] as? String,
               let messageData = messageString.data(using: .utf8),
               let payload = try? JSONDecoder().decode([String: [ShoppingItem]].self, from: messageData),
               let items = payload["items"] {
                DispatchQueue.main.async {
                    self?.observingItems = items
                }
            }
        }.resume()
    }
    
    func addFriend(code: String, name: String) {
        let newFriend = Friend(name: name, code: code.uppercased())
        if !friends.contains(where: { $0.code == newFriend.code }) {
            friends.append(newFriend)
            saveFriends()
        }
    }
}
