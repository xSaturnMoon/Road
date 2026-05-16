import Foundation
import Combine

class ShoppingManager: ObservableObject {
    static let shared = ShoppingManager()

    @Published var items: [ShoppingItem] = []

    private let itemsKey = "bloom_shopping_items"
    private let sb = SupabaseManager.shared

    init() {
        loadLocalItems()
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

    // MARK: - Cloud Sync

    private func syncToCloud(_ item: ShoppingItem) {
        guard sb.isAuthenticated else { return }
        Task { try? await sb.upsertShoppingItem(item) }
    }
}
