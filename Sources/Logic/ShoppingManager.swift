import Foundation
import Combine

class ShoppingManager: ObservableObject {
    static let shared = ShoppingManager()

    @Published var items: [ShoppingItem] = []
    @Published var friends: [Friend] = []
    @Published var observingFriend: Friend?
    @Published var observingItems: [ShoppingItem] = []
    @Published var myCode: String = ""

    private let itemsKey = "bloom_shopping_items"
    private let friendsKey = "bloom_friends"
    private let sb = SupabaseManager.shared

    init() {
        loadLocalItems()
        loadFriends()
        generateMyCode()
    }

    // MARK: - Local Persistence

    private func loadLocalItems() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            self.items = decoded
        }
    }

    private func saveLocalItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: itemsKey)
        }
    }

    func loadFriends() {
        if let data = UserDefaults.standard.data(forKey: friendsKey),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            self.friends = decoded
        }
    }

    func saveFriends() {
        if let encoded = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(encoded, forKey: friendsKey)
        }
    }

    private func generateMyCode() {
        if let savedCode = UserDefaults.standard.string(forKey: "bloom_my_code") {
            self.myCode = savedCode
        } else {
            let newCode = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
            UserDefaults.standard.set(newCode, forKey: "bloom_my_code")
            self.myCode = newCode
        }
    }

    /// Called after login to replace local data with cloud data
    func replaceWithCloudData(_ cloudItems: [ShoppingItem]) {
        items = cloudItems
        saveLocalItems()
    }

    // MARK: - CRUD (Local + Cloud)

    func addItem(name: String, quantity: String) {
        let newItem = ShoppingItem(name: name, quantity: quantity)
        items.insert(newItem, at: 0)
        saveLocalItems()
        syncToCloud(newItem)
    }

    func toggleItem(_ item: ShoppingItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isChecked.toggle()
            saveLocalItems()
            syncToCloud(items[index])
        }
    }

    func deleteItem(_ item: ShoppingItem) {
        items.removeAll(where: { $0.id == item.id })
        saveLocalItems()
        Task { try? await sb.deleteShoppingItem(id: item.id) }
    }

    func clearChecked() {
        let toDelete = items.filter { $0.isChecked }
        items.removeAll(where: { $0.isChecked })
        saveLocalItems()
        for item in toDelete {
            Task { try? await sb.deleteShoppingItem(id: item.id) }
        }
    }

    func clearAll() {
        let toDelete = items
        items.removeAll()
        saveLocalItems()
        for item in toDelete {
            Task { try? await sb.deleteShoppingItem(id: item.id) }
        }
    }

    func addFriend(code: String, name: String) {
        let newFriend = Friend(name: name, code: code)
        if !friends.contains(where: { $0.code == code }) {
            friends.append(newFriend)
            saveFriends()
        }
    }

    func fetchItemsForFriend(_ friend: Friend) {
        observingFriend = friend
        observingItems = [] // Loading state or clear old data
        Task {
            do {
                if let profile = try await sb.findProfileByCode(friend.code) {
                    let sbItems = try await sb.fetchShoppingItems(forUserId: profile.userId)
                    let domainItems = sbItems.map { 
                        ShoppingItem(id: UUID(uuidString: $0.id) ?? UUID(), name: $0.name, quantity: $0.quantity, isChecked: $0.is_checked)
                    }
                    await MainActor.run {
                        self.observingItems = domainItems
                    }
                }
            } catch {
                print("Errore fetch lista amico: \(error)")
            }
        }
    }

    // MARK: - Cloud Sync

    private func syncToCloud(_ item: ShoppingItem) {
        guard sb.isAuthenticated else { return }
        Task { try? await sb.upsertShoppingItem(item) }
    }
}
