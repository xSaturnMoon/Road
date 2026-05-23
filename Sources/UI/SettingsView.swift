import SwiftUI
import AudioToolbox

// MARK: - Settings View

struct SettingsView: View {
    @StateObject var auth = AuthManager.shared
    @StateObject var updateManager = UpdateManager.shared
    @State private var showingAuthModal = false
    @State private var showLogoutAlert = false
    @State private var showUpdateSheet = false
    @State private var showUpdateAlert = false
    @State private var isCheckingUpdate = false
    @State private var updateInfo: UpdateInfo?
    @StateObject private var downloader = IPADownloader()
    
    @AppStorage("theme") private var theme: String = "Sistema"
    @AppStorage("notificationSound") private var notificationSound: String = "Predefinito"
    
    private var appVersion: String {
        if let url = Bundle.main.url(forResource: "version", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = json["version"] as? String {
            return version
        }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    let themes = ["Sistema", "Chiaro", "Scuro"]
    let sounds = ["Predefinito", "Nessuno", "Tri-tone", "Anticipate", "Bloom", "Calypso", "Chime", "Chord", "Descent", "Fanfare", "Glass", "Hero", "Horn", "Ladder", "Minuet", "News Flash", "Noir", "Sherwood Forest", "Spell", "Suspense", "Telegraph", "Tiptoes", "Typewriters", "Update"]

    var body: some View {
        NavigationStack {
            Form {
                if let user = auth.currentUser {
                    // Profile Section
                    Section {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.systemGray3))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle().stroke(Color(UIColor.systemGray5), lineWidth: 1)
                                    )
                                Text(String(user.email.prefix(1)).uppercased())
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                            }
                            
                            Text(user.email)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Account Section
                    Section("Account") {
                        NavigationLink(destination: ChangePasswordView()) {
                            Text("Cambia Password")
                        }
                        Button(role: .destructive) {
                            showLogoutAlert = true
                        } label: {
                            Text("Esci")
                                .foregroundStyle(.red)
                        }
                    }
                } else {
                    Section {
                        Button {
                            showingAuthModal = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2)
                                Text("Accedi o Registrati")
                            }
                        }
                    }
                }
                
                // App Section
                Section("App") {
                    NavigationLink(destination: Text("Icona App")) {
                        Text("Icona App")
                    }
                    Picker("Tema", selection: $theme) {
                        ForEach(themes, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Text("Versione App")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Sound Section
                Section("Sound") {
                    Picker("Suono Notifiche", selection: $notificationSound) {
                        ForEach(sounds, id: \.self) {
                            Text($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: notificationSound) { _, newValue in
                        var id: UInt32 = 0
                        switch newValue {
                        case "Predefinito": id = 1005
                        case "Tri-tone": id = 1007
                        case "Chime": id = 1008
                        case "Glass": id = 1009
                        case "Horn": id = 1010
                        case "Anticipate": id = 1013
                        case "Bloom": id = 1014
                        case "Calypso": id = 1015
                        case "Minuet": id = 1020
                        case "News Flash": id = 1021
                        case "Sherwood Forest": id = 1022
                        case "Telegraph": id = 1023
                        case "Tiptoes": id = 1024
                        case "Typewriters": id = 1025
                        case "Update": id = 1026
                        case "Chord": id = 1300
                        case "Descent": id = 1301
                        case "Fanfare": id = 1302
                        case "Hero": id = 1303
                        case "Ladder": id = 1304
                        case "Noir": id = 1305
                        case "Spell": id = 1306
                        case "Suspense": id = 1307
                        default: break
                        }
                        if id != 0 {
                            AudioServicesPlaySystemSound(id)
                        }
                    }
                }
                
                // Aggiornamenti Section
                Section("Aggiornamenti") {
                    Button {
                        checkForUpdates()
                    } label: {
                        HStack {
                            Text("Controlla Aggiornamenti")
                                .foregroundColor(.primary)
                            Spacer()
                            if isCheckingUpdate {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color(UIColor.tertiaryLabel))
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Conferma Uscita", isPresented: $showLogoutAlert) {
                Button("Annulla", role: .cancel) { }
                Button(auth.isSyncing ? "Salvataggio..." : "Esci", role: .destructive) {
                    auth.logout()
                }
                .disabled(auth.isSyncing)
            } message: {
                Text("Prima di uscire, tutti i tuoi dati verranno salvati su Bloom Cloud.")
            }
            .sheet(isPresented: $showUpdateSheet) {
                if let info = updateInfo {
                    VStack(spacing: 24) {
                        Capsule()
                            .fill(Color(UIColor.systemGray4))
                            .frame(width: 40, height: 5)
                            .padding(.top, 16)
                        
                        Text("Bloom")
                            .font(.title2.bold())
                        Text("Versione \(info.version)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text(info.notes)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button("Non ora") {
                                showUpdateSheet = false
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(12)
                            
                            Button("Installa") {
                                if let url = URL(string: info.url) {
                                    downloader.download(from: url)
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                            .disabled(downloader.isDownloading)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, downloader.isDownloading || downloader.isFinished ? 8 : 24)
                        
                        Group {
                            if downloader.isDownloading {
                                VStack(spacing: 8) {
                                    ProgressView(value: downloader.progress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    Text("Scaricamento in corso... \(Int(downloader.progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            } else if downloader.isFinished {
                                Text("✅ Download completato!")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                                    .padding()
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .presentationDetents([.medium])
                }
            }
            .alert("Nessun aggiornamento", isPresented: $showUpdateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Sei aggiornato! Stai usando l'ultima versione disponibile.")
            }
            .fullScreenCover(isPresented: $showingAuthModal) {
                AuthView(isPresented: $showingAuthModal, isOptional: true)
            }
        }
    }
    func checkForUpdates() {
        isCheckingUpdate = true
        Task {
            do {
                guard let url = URL(string: "https://raw.githubusercontent.com/xSaturnMoon/Bloom/main/update.json") else { return }
                let (data, _) = try await URLSession.shared.data(from: url)
                let info = try JSONDecoder().decode(UpdateInfo.self, from: data)
                let currentVersion = appVersion
                
                await MainActor.run {
                    self.isCheckingUpdate = false
                    if info.version != currentVersion {
                        self.updateInfo = info
                        self.showUpdateSheet = true
                    } else {
                        self.showUpdateAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCheckingUpdate = false
                    self.showUpdateAlert = true
                }
            }
        }
    }
}

struct UpdateInfo: Codable {
    let version: String
    let notes: String
    let url: String
}

// MARK: - Downloader

class IPADownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var progress: Double = 0
    @Published var isDownloading = false
    @Published var isFinished = false
    
    func download(from url: URL) {
        DispatchQueue.main.async {
            self.isDownloading = true
            self.progress = 0
            self.isFinished = false
        }
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        let task = session.downloadTask(with: url)
        task.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            DispatchQueue.main.async {
                self.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("Bloom.ipa")
        try? FileManager.default.removeItem(at: tempUrl)
        try? FileManager.default.moveItem(at: location, to: tempUrl)
        
        DispatchQueue.main.async {
            self.isDownloading = false
            self.isFinished = true
            
            // Present Document Picker to save to Files (Downloads)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                let documentPicker = UIDocumentPickerViewController(forExporting: [tempUrl], asCopy: true)
                documentPicker.allowsMultipleSelection = false
                root.present(documentPicker, animated: true)
            }
        }
    }
}

// MARK: - Auth View (Native Redesign)

struct AuthView: View {
    @Binding var isPresented: Bool
    var isOptional: Bool = true
    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @StateObject var auth = AuthManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 32)
                    
                    Text("Bloom")
                        .font(.system(.title, design: .rounded, weight: .semibold))
                    
                    Text(isLogin ? "Accedi per continuare" : "Crea un nuovo account")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Picker("Modalità", selection: $isLogin) {
                        Text("Accedi").tag(true)
                        Text("Registrati").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                }
                .padding(.bottom, 16)
                .background(Color(UIColor.systemGroupedBackground))
                
                // Form
                Form {
                    Section {
                        if !isLogin {
                            TextField("Nome completo", text: $name)
                        }
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Password", text: $password)
                    } footer: {
                        if let error = auth.authError {
                            Text(error)
                                .foregroundColor(.red)
                        }
                    }
                    
                    Section {
                        Button {
                            triggerAuth()
                        } label: {
                            if auth.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text(isLogin ? "Accedi" : "Crea Account")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .formStyle(.grouped)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isOptional {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Annulla") {
                            isPresented = false
                        }
                    }
                }
            }
            .onChange(of: auth.currentUser?.id) { _, _ in
                if auth.currentUser != nil {
                    isPresented = false
                }
            }
        }
    }

    private func triggerAuth() {
        auth.authError = nil
        if isLogin {
            auth.login(email: email, password: password)
        } else {
            auth.signUp(email: email, name: name, password: password)
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @StateObject var auth = AuthManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        Form {
            Section {
                SecureField("Vecchia Password", text: $oldPassword)
                SecureField("Nuova Password", text: $newPassword)
                SecureField("Conferma Nuova Password", text: $confirmPassword)
            }
            
            if let error = errorMessage {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            if let success = successMessage {
                Text(success).foregroundColor(.green).font(.footnote)
            }
            
            Button(action: changePassword) {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Aggiorna Password")
                }
            }
            .disabled(isLoading || oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
        }
        .navigationTitle("Cambia Password")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func changePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Le nuove password non corrispondono."
            return
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await auth.changePassword(old: oldPassword, new: newPassword)
                await MainActor.run {
                    isLoading = false
                    successMessage = "Password aggiornata con successo!"
                    oldPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
