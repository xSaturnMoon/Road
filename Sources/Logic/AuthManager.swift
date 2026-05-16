import Foundation
import SwiftUI
import Combine

struct BloomUser: Codable, Identifiable {
    var id = UUID()
    var name: String
    var email: String
    var password: String // In una vera app questa sarebbe criptata
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: BloomUser?
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var isLoading = false
    @Published var authError: String?
    
    private let usersKey = "bloom_registered_users"
    private let sessionKey = "bloom_current_session"
    
    init() {
        loadSession()
    }
    
    private func loadSession() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let user = try? JSONDecoder().decode(BloomUser.self, from: data) {
            self.currentUser = user
        }
    }
    
    private func saveSession(_ user: BloomUser?) {
        if let user = user, let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }
    
    private func getRegisteredUsers() -> [BloomUser] {
        if let data = UserDefaults.standard.data(forKey: usersKey),
           let users = try? JSONDecoder().decode([BloomUser].self, from: data) {
            return users
        }
        return []
    }
    
    private func saveRegisteredUsers(_ users: [BloomUser]) {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: usersKey)
        }
    }
    
    func login(email: String, password: String) {
        isLoading = true
        authError = nil
        
        // Simuliamo un caricamento di rete "Wow"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let users = self.getRegisteredUsers()
            if let user = users.first(where: { $0.email.lowercased() == email.lowercased() && $0.password == password }) {
                self.currentUser = user
                self.saveSession(user)
                self.lastSyncDate = Date()
                self.isLoading = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else {
                self.authError = "Email o Password errati. Riprova."
                self.isLoading = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    func signUp(email: String, name: String, password: String) {
        isLoading = true
        authError = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            var users = self.getRegisteredUsers()
            
            if users.contains(where: { $0.email.lowercased() == email.lowercased() }) {
                self.authError = "Questa email è già registrata."
                self.isLoading = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            
            let newUser = BloomUser(name: name, email: email, password: password)
            users.append(newUser)
            self.saveRegisteredUsers(users)
            
            self.currentUser = newUser
            self.saveSession(newUser)
            self.lastSyncDate = Date()
            self.isLoading = false
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    func logout() {
        currentUser = nil
        saveSession(nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
