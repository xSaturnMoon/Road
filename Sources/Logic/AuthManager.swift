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
                let user = BloomUser(
                    name: sbUser.userMetadata?.name ?? email.components(separatedBy: "@").first ?? "Utente",
                    email: email,
                    supabaseId: sbUser.id
                )
                await MainActor.run {
                    self.currentUser = user
                    self.saveLocalSession(user)
                    self.isLoading = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                // syncAfterLogin handles fetchOrCreateProfile + all data sync
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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                // Sync after signup to create profile + upload any local data
                await syncAfterLogin()
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
            await MainActor.run { isSyncing = true }
            // Force-upload EVERYTHING to cloud before clearing local storage.
            // This saves any items whose background sync failed (e.g. expired token, network blip).
            await uploadAllLocalToCloud()
            await sb.signOut()
            await MainActor.run {
                self.isSyncing = false
                self.currentUser = nil
                self.saveLocalSession(nil)
                // Clear ALL local user data so a new login starts fresh
                CalendarManager.shared.clearLocalData()
                ShoppingManager.shared.clearLocalData()
                WeatherManager.shared.clearLocalData()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    /// Force-uploads every piece of local data to Supabase.
    /// Called before logout so nothing is silently lost due to failed background syncs.
    private func uploadAllLocalToCloud() async {
        guard sb.isAuthenticated else { return }

        let localEvents  = await MainActor.run { CalendarManager.shared.events }
        let localItems   = await MainActor.run { ShoppingManager.shared.items }
        let localFriends = await MainActor.run { ShoppingManager.shared.friends }
        let localLocs    = await MainActor.run { WeatherManager.shared.locations }

        for event in localEvents  { try? await sb.upsertEvent(event) }
        for item  in localItems   { try? await sb.upsertShoppingItem(item) }
        for friend in localFriends { try? await sb.upsertFriend(friend) }
        for loc   in localLocs    { try? await sb.upsertWeatherLocation(loc) }
    }

    func changePassword(old: String, new: String) async throws {
        guard let email = currentUser?.email else { throw SupabaseError.notAuthenticated }
        _ = try await sb.signIn(email: email, password: old)
        try await sb.updatePassword(newPassword: new)
    }

    // MARK: - Cloud Sync (Merge Strategy)

    func syncAfterLogin() async {
        await MainActor.run { isSyncing = true }

        // 1. Fetch/create friend code (single call)
        if let newFriendCode = try? await sb.fetchOrCreateProfile() {
            await MainActor.run {
                if self.currentUser != nil {
                    self.currentUser?.friendCode = newFriendCode
                    self.saveLocalSession(self.currentUser)
                    ShoppingManager.shared.myCode = newFriendCode
                }
            }
        }

        // 2. Sync Calendar Events — merge: upload local-only, then replace
        if let cloudEvents = try? await sb.fetchEvents() {
            let cloudBloomEvents = cloudEvents.map { $0.toBloomEvent() }
            let localEvents = await MainActor.run { CalendarManager.shared.events }
            let cloudIds = Set(cloudBloomEvents.map { $0.id })
            let localOnly = localEvents.filter { !cloudIds.contains($0.id) }
            // Upload local-only events to cloud so they are not lost
            for event in localOnly {
                try? await sb.upsertEvent(event)
            }
            let merged = cloudBloomEvents + localOnly
            await MainActor.run {
                CalendarManager.shared.replaceWithCloudData(merged)
            }
        }

        // 3. Sync Shopping Items — merge: upload local-only, then replace
        if let cloudItems = try? await sb.fetchShoppingItems() {
            let cloudShopItems = cloudItems.map { $0.toShoppingItem() }
            let localItems = await MainActor.run { ShoppingManager.shared.items }
            let cloudIds = Set(cloudShopItems.map { $0.id })
            let localOnly = localItems.filter { !cloudIds.contains($0.id) }
            for item in localOnly {
                try? await sb.upsertShoppingItem(item)
            }
            let merged = cloudShopItems + localOnly
            await MainActor.run {
                ShoppingManager.shared.replaceWithCloudData(merged)
            }
        }

        // 4. Sync Friends — merge: upload local-only, then replace
        if let cloudFriends = try? await sb.fetchFriends() {
            let cloudFriendItems = cloudFriends.map { $0.toFriend() }
            let localFriends = await MainActor.run { ShoppingManager.shared.friends }
            let cloudIds = Set(cloudFriendItems.map { $0.id })
            let localOnly = localFriends.filter { !cloudIds.contains($0.id) }
            for friend in localOnly {
                try? await sb.upsertFriend(friend)
            }
            let merged = cloudFriendItems + localOnly
            await MainActor.run {
                ShoppingManager.shared.replaceWithCloudFriends(merged)
            }
        }

        // 5. Sync Weather Locations — merge: upload local-only, then replace
        if let cloudLocs = try? await sb.fetchWeatherLocations() {
            let cloudLocItems = cloudLocs.map { $0.toWeatherLocation() }
            let localLocs = await MainActor.run { WeatherManager.shared.locations }
            let cloudIds = Set(cloudLocItems.map { $0.id })
            let localOnly = localLocs.filter { !cloudIds.contains($0.id) }
            for loc in localOnly {
                try? await sb.upsertWeatherLocation(loc)
            }
            let merged = cloudLocItems + localOnly
            await MainActor.run {
                WeatherManager.shared.replaceWithCloudLocations(merged)
            }
        }

        await MainActor.run {
            isSyncing = false
            lastSyncDate = Date()
        }
    }
}
