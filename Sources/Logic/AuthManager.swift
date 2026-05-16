import Foundation
import SwiftUI

struct BloomUser: Codable, Identifiable {
    var id = UUID()
    var name: String
    var email: String
    var supabaseId: String?
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
    }

    var isLoggedIn: Bool { currentUser != nil && sb.isAuthenticated }

    // MARK: - Session

    private func loadLocalSession() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let user = try? JSONDecoder().decode(BloomUser.self, from: data) {
            currentUser = user
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
                let user = BloomUser(
                    name: sbUser.userMetadata?.name ?? email.components(separatedBy: "@").first ?? "Utente",
                    email: email,
                    supabaseId: sbUser.id
                )
                await MainActor.run {
                    self.currentUser = user
                    self.saveLocalSession(user)
                    self.isLoading = false
                    self.lastSyncDate = Date()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                // Sync cloud data after login
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
                let user = BloomUser(name: name, email: email, supabaseId: sbUser.id)
                await MainActor.run {
                    self.currentUser = user
                    self.saveLocalSession(user)
                    self.isLoading = false
                    self.lastSyncDate = Date()
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    // MARK: - Cloud Sync

    private func syncAfterLogin() async {
        await MainActor.run { isSyncing = true }

        do {
            // Sync calendar events
            let cloudEvents = try await sb.fetchEvents()
            let bloomEvents = cloudEvents.map { $0.toBloomEvent() }
            await MainActor.run {
                CalendarManager.shared.replaceWithCloudData(bloomEvents)
            }

            // Sync shopping items
            let cloudItems = try await sb.fetchShoppingItems()
            let shopItems = cloudItems.map { $0.toShoppingItem() }
            await MainActor.run {
                ShoppingManager.shared.replaceWithCloudData(shopItems)
            }

            await MainActor.run {
                isSyncing = false
                lastSyncDate = Date()
            }
        } catch {
            await MainActor.run { isSyncing = false }
        }
    }
}
