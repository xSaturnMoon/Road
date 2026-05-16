import Foundation

// MARK: - Supabase Response Models

struct SupabaseUser: Codable {
    let id: String
    let email: String?
    let userMetadata: UserMetadata?

    struct UserMetadata: Codable {
        let name: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, email
        case userMetadata = "user_metadata"
    }
}

struct SupabaseAuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseEvent: Codable {
    let id: String
    let userId: String
    let title: String
    let date: String
    let startTime: String
    let endTime: String?
    let hasEndTime: Bool
    let isCompleted: Bool
    let reminderId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, date
        case startTime = "start_time"
        case endTime = "end_time"
        case hasEndTime = "has_end_time"
        case isCompleted = "is_completed"
        case reminderId = "reminder_id"
    }

    func toBloomEvent() -> BloomEvent {
        let fmt = ISO8601DateFormatter()
        return BloomEvent(
            id: UUID(uuidString: id) ?? UUID(),
            title: title,
            date: fmt.date(from: date) ?? Date(),
            startTime: fmt.date(from: startTime) ?? Date(),
            endTime: endTime.flatMap { fmt.date(from: $0) },
            hasEndTime: hasEndTime,
            isCompleted: isCompleted,
            reminderId: reminderId
        )
    }
}

struct SupabaseShoppingItem: Codable {
    let id: String
    let userId: String
    let name: String
    let quantity: String
    let isChecked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, quantity
        case isChecked = "is_checked"
    }

    func toShoppingItem() -> ShoppingItem {
        ShoppingItem(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            quantity: quantity,
            isChecked: isChecked
        )
    }
}

// MARK: - Model Extensions

extension BloomEvent {
    func toSupabaseDict(userId: String) -> [String: Any] {
        let fmt = ISO8601DateFormatter()
        var dict: [String: Any] = [
            "id": id.uuidString,
            "user_id": userId,
            "title": title,
            "date": fmt.string(from: date),
            "start_time": fmt.string(from: startTime),
            "has_end_time": hasEndTime,
            "is_completed": isCompleted
        ]
        if let et = endTime { dict["end_time"] = fmt.string(from: et) }
        if let rid = reminderId { dict["reminder_id"] = rid }
        return dict
    }
}

extension ShoppingItem {
    func toSupabaseDict(userId: String) -> [String: Any] {
        return [
            "id": id.uuidString,
            "user_id": userId,
            "name": name,
            "quantity": quantity,
            "is_checked": isChecked
        ]
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case invalidURL
    case notAuthenticated
    case apiError(String)
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL non valido"
        case .notAuthenticated: return "Non sei autenticato"
        case .apiError(let msg): return msg
        case .httpError(let code): return "Errore HTTP \(code)"
        }
    }
}

// MARK: - Supabase Manager

class SupabaseManager {
    static let shared = SupabaseManager()

    private let base = SupabaseConfig.url
    private let key  = SupabaseConfig.anonKey

    private(set) var accessToken: String?
    private(set) var userId: String?

    private init() {
        accessToken = UserDefaults.standard.string(forKey: "sb_access_token")
        userId      = UserDefaults.standard.string(forKey: "sb_user_id")
    }

    var isAuthenticated: Bool { accessToken != nil && userId != nil }

    // MARK: - Session helpers

    private func saveSession(_ r: SupabaseAuthResponse) {
        accessToken = r.accessToken
        userId      = r.user.id
        UserDefaults.standard.set(r.accessToken, forKey: "sb_access_token")
        UserDefaults.standard.set(r.user.id,     forKey: "sb_user_id")
        UserDefaults.standard.set(r.refreshToken, forKey: "sb_refresh_token")
    }

    func clearSession() {
        accessToken = nil
        userId      = nil
        UserDefaults.standard.removeObject(forKey: "sb_access_token")
        UserDefaults.standard.removeObject(forKey: "sb_user_id")
        UserDefaults.standard.removeObject(forKey: "sb_refresh_token")
    }

    // MARK: - Auth

    func signUp(email: String, password: String, name: String) async throws -> SupabaseUser {
        let body: [String: Any] = ["email": email, "password": password, "data": ["name": name]]
        let r: SupabaseAuthResponse = try await post(path: "/auth/v1/signup", body: body, useAuth: false)
        saveSession(r)
        return r.user
    }

    func signIn(email: String, password: String) async throws -> SupabaseUser {
        let body: [String: Any] = ["email": email, "password": password]
        let r: SupabaseAuthResponse = try await post(path: "/auth/v1/token?grant_type=password", body: body, useAuth: false)
        saveSession(r)
        return r.user
    }

    func signOut() async {
        guard let token = accessToken else { clearSession(); return }
        var req = makeRequest(path: "/auth/v1/logout", method: "POST")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
        clearSession()
    }

    // MARK: - Calendar Events CRUD

    func fetchEvents() async throws -> [SupabaseEvent] {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        return try await get(path: "/rest/v1/calendar_events?user_id=eq.\(uid)&select=*&order=date.asc")
    }

    func upsertEvent(_ event: BloomEvent) async throws {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        let body = event.toSupabaseDict(userId: uid)
        let _: [SupabaseEvent] = try await post(
            path: "/rest/v1/calendar_events",
            body: body,
            useAuth: true,
            prefer: "resolution=merge-duplicates,return=representation"
        )
    }

    func deleteEvent(id: UUID) async throws {
        try await delete(path: "/rest/v1/calendar_events?id=eq.\(id.uuidString)")
    }

    // MARK: - Shopping Items CRUD

    func fetchShoppingItems() async throws -> [SupabaseShoppingItem] {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        return try await get(path: "/rest/v1/shopping_items?user_id=eq.\(uid)&select=*&order=created_at.asc")
    }

    func upsertShoppingItem(_ item: ShoppingItem) async throws {
        guard let uid = userId else { throw SupabaseError.notAuthenticated }
        let body = item.toSupabaseDict(userId: uid)
        let _: [SupabaseShoppingItem] = try await post(
            path: "/rest/v1/shopping_items",
            body: body,
            useAuth: true,
            prefer: "resolution=merge-duplicates,return=representation"
        )
    }

    func deleteShoppingItem(id: UUID) async throws {
        try await delete(path: "/rest/v1/shopping_items?id=eq.\(id.uuidString)")
    }

    // MARK: - HTTP Helpers

    private func makeRequest(path: String, method: String = "GET") -> URLRequest {
        let url = URL(string: base + path)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let req = makeRequest(path: path)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(data: data, response: resp)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func post<T: Decodable>(path: String, body: [String: Any], useAuth: Bool, prefer: String? = nil) async throws -> T {
        var req = makeRequest(path: path, method: "POST")
        if !useAuth { req.setValue(nil, forHTTPHeaderField: "Authorization") }
        if let p = prefer { req.setValue(p, forHTTPHeaderField: "Prefer") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(data: data, response: resp)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func delete(path: String) async throws {
        var req = makeRequest(path: path, method: "DELETE")
        req.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try checkStatus(data: data, response: resp)
    }

    private func checkStatus(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode >= 400 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["message"] as? String ?? json["msg"] as? String {
                throw SupabaseError.apiError(msg)
            }
            throw SupabaseError.httpError(http.statusCode)
        }
    }
}
