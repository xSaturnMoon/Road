import Foundation
import SwiftUI

struct BloomUser: Codable, Identifiable {
    var id = UUID()
    var name: String
    var email: String
    var supabaseId: String?
    var friendCode: String?
}

class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: BloomUser?
    @Published var isLoading = false
    @Published var authError: String?
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    private let sb = SupabaseManager.shared
    private let sessionKey = "bloom_current_user"

    init() {
        loadLocalSession()
        if isLoggedIn {
            Task {
                await syncAfterLogin()
            }
        }
    }

    var isLoggedIn: Bool { currentUser != nil && sb.isAuthenticated }

    // MARK: - Session

    private func loadLocalSession() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let user = try? JSONDecoder().decode(BloomUser.self, from: data) {
            currentUser = user
            if let code = user.friendCode {
                ShoppingManager.shared.myCode = code
            }
        }
    }

    private func saveLocalSession(_ user: BloomUser?) {
        if let u = user, let enc = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(enc, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }

    // MARK: - Auth

    func login(email: String, password: String) {
        isLoading = true
        authError = nil

        Task {
            do {
                let sbUser = try await sb.signIn(email: email, password: password)
                var user = BloomUser(
                    name: sbUser.userMetadata?.name ?? email.components(separatedBy: "@").first ?? "Utente",
                    email: email,
                    supabaseId: sbUser.id
                )
                // Carica il codice amico permanente da Supabase
                let friendCode = try? await sb.fetchOrCreateProfile()
                user.friendCode = friendCode
                let finalUser = user
                await MainActor.run {
                    self.currentUser = finalUser
                    self.saveLocalSession(finalUser)
                    self.isLoading = false
                    self.lastSyncDate = Date()
                    // Aggiorna anche ShoppingManager con il codice definitivo
                    if let code = friendCode {
                        ShoppingManager.shared.myCode = code
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                await syncAfterLogin()
            } catch {
                await MainActor.run {
                    self.authError = "Email o password errati."
                    self.isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    func signUp(email: String, name: String, password: String) {
        isLoading = true
        authError = nil

        Task {
            do {
                let sbUser = try await sb.signUp(email: email, password: password, name: name)
                var user = BloomUser(name: name, email: email, supabaseId: sbUser.id)
                // Crea il codice amico permanente su Supabase
                let friendCode = try? await sb.fetchOrCreateProfile()
                user.friendCode = friendCode
                let finalUser = user
                await MainActor.run {
                    self.currentUser = finalUser
                    self.saveLocalSession(finalUser)
                    self.isLoading = false
                    self.lastSyncDate = Date()
                    if let code = friendCode {
                        ShoppingManager.shared.myCode = code
                    }
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.authError = error.localizedDescription
                    self.isLoading = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    func logout() {
        Task {
            await sb.signOut()
            await MainActor.run {
                self.currentUser = nil
                self.saveLocalSession(nil)
                ShoppingManager.shared.myCode = ""
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    // MARK: - Cloud Sync

    private func syncAfterLogin() async {
        await MainActor.run { isSyncing = true }

        // 1. Fetch or create friend code first! (So it never fails if tables are missing)
        if let newFriendCode = try? await sb.fetchOrCreateProfile() {
            await MainActor.run {
                if self.currentUser != nil {
                    self.currentUser?.friendCode = newFriendCode
                    self.saveLocalSession(self.currentUser)
                    ShoppingManager.shared.myCode = newFriendCode
                }
            }
        }

        // 2. Fetch Events
        if let cloudEvents = try? await sb.fetchEvents() {
            let bloomEvents = cloudEvents.map { $0.toBloomEvent() }
            await MainActor.run {
                CalendarManager.shared.replaceWithCloudData(bloomEvents)
            }
        }

        // 3. Fetch Items
        if let cloudItems = try? await sb.fetchShoppingItems() {
            let shopItems = cloudItems.map { $0.toShoppingItem() }
            await MainActor.run {
                ShoppingManager.shared.replaceWithCloudData(shopItems)
            }
        }

        await MainActor.run {
            isSyncing = false
            lastSyncDate = Date()
        }
    }
}
