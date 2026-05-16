import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: UserAccount?
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private let userKey = "bloom_user_account"
    
    init() {
        loadUser()
    }
    
    func loadUser() {
        if let data = UserDefaults.standard.data(forKey: userKey),
           let decoded = try? JSONDecoder().decode(UserAccount.self, from: data) {
            self.currentUser = decoded
        }
    }
    
    func signUp(email: String, name: String) {
        let newUser = UserAccount(email: email, name: name)
        self.currentUser = newUser
        saveUser()
        performInitialSync()
    }
    
    func login(email: String) {
        // In a real app, this would verify password.
        // For Bloom, we'll fetch existing data from cloud based on email.
        self.currentUser = UserAccount(email: email, name: email.components(separatedBy: "@").first ?? "Utente")
        saveUser()
        performInitialSync()
    }
    
    func logout() {
        self.currentUser = nil
        UserDefaults.standard.removeObject(forKey: userKey)
    }
    
    func saveUser() {
        if let encoded = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
    }
    
    func performInitialSync() {
        guard let user = currentUser else { return }
        isSyncing = true
        
        // Simulate cloud fetch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isSyncing = false
            self.lastSyncDate = Date()
            // Here we would call ShoppingManager.shared.syncFromCloud() etc.
        }
    }
}

struct UserAccount: Codable {
    var id = UUID()
    var email: String
    var name: String
}
