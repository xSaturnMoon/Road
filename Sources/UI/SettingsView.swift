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
    
    @AppStorage("theme") private var theme: String = "Sistema"
    @AppStorage("notificationSound") private var notificationSound: String = "Predefinito"
    
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
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
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
                Button("Esci", role: .destructive) {
                    auth.logout()
                }
            } message: {
                Text("Sei sicuro di voler uscire dal tuo account?")
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
                                if let encodedURL = info.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                                   let installURL = URL(string: "livecontainer://install?url=\(encodedURL)") {
                                    UIApplication.shared.open(installURL)
                                }
                                showUpdateSheet = false
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
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
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                
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

// MARK: - Auth View (Glassmorphism Redesign)

struct AuthView: View {
    @Binding var isPresented: Bool
    var isOptional: Bool = true
    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @StateObject var auth = AuthManager.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var cardScale: CGFloat = 0.92
    @State private var cardOpacity: Double = 0
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────
            BlueBackground()
                .ignoresSafeArea()

            // ── Close Button (top-right) ────────────────────────────
            if isOptional {
                VStack {
                    HStack {
                        Spacer()
                        Button { isPresented = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                    }
                    Spacer()
                }
            }

            // ── Glass Card ──────────────────────────────────────────
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 80)

                    VStack(spacing: 28) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 88, height: 88)
                                .overlay(
                                    Circle().stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)

                            Image(systemName: isLogin ? "lock.shield.fill" : "person.fill.badge.plus")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "6BAAFF"), Color(hex: "2A6FE8")],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .contentTransition(.symbolEffect(.replace))
                        }

                        // Titles
                        VStack(spacing: 6) {
                            Text(isLogin ? "Bentornato" : "Crea Account")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text(isLogin
                                 ? "Inserisci le credenziali per accedere"
                                 : "Registrati per sincronizzare i tuoi dati")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Form
                        VStack(spacing: 14) {
                            if !isLogin {
                                BloomField(
                                    placeholder: "Nome completo",
                                    icon: "person",
                                    text: $name
                                )
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                            }

                            BloomField(
                                placeholder: "Email",
                                icon: "envelope",
                                text: $email,
                                keyboard: .emailAddress,
                                autocap: .none
                            )

                            BloomField(
                                placeholder: "Password",
                                icon: "key",
                                text: $password,
                                isSecure: true
                            )
                        }
                        .offset(x: shakeOffset)

                        // Error message
                        if let error = auth.authError {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .foregroundColor(.red)
                            }
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }

                        // Primary CTA
                        Button { triggerAuth() } label: {
                            Group {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    HStack(spacing: 8) {
                                        Text(isLogin ? "Accedi" : "Crea Account")
                                            .font(.system(size: 17, weight: .semibold))
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "4F8EF7"), Color(hex: "1A5FD4")],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                            .shadow(color: Color(hex: "1A5FD4").opacity(0.4), radius: 12, y: 6)
                        }
                        .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
                        .opacity((auth.isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1)
                        .scaleEffect(auth.isLoading ? 0.97 : 1.0)
                        .animation(.spring(response: 0.3), value: auth.isLoading)

                        // Toggle login/register
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                isLogin.toggle()
                                auth.authError = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isLogin ? "Non hai un account?" : "Hai già un account?")
                                    .foregroundStyle(.secondary)
                                Text(isLogin ? "Registrati" : "Accedi")
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: "4F8EF7"))
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.5), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 30, y: 10)
                    .padding(.horizontal, 20)
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)

                    Spacer(minLength: 40)
                }
            }
        }
        .preferredColorScheme(nil)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isLogin)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                cardScale  = 1.0
                cardOpacity = 1.0
            }
        }
        .onChange(of: auth.authError) { _, error in
            if error != nil { performShake() }
        }
        .onChange(of: auth.currentUser?.id) { _, _ in
            if auth.currentUser != nil {
                withAnimation { isPresented = false }
            }
        }
    }

    private func triggerAuth() {
        withAnimation { auth.authError = nil }
        if isLogin {
            auth.login(email: email, password: password)
        } else {
            auth.signUp(email: email, name: name, password: password)
        }
    }

    private func performShake() {
        let steps: [CGFloat] = [0, 12, -12, 9, -9, 5, -5, 0]
        for (i, offset) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.055) {
                withAnimation(.spring(response: 0.12, dampingFraction: 0.3)) {
                    shakeOffset = offset
                }
            }
        }
    }
}

// MARK: - Background (Solo Blu, Light/Dark adaptive)

private struct BlueBackground: View {
    @Environment(\.colorScheme) var cs
    @State private var phase1 = false
    @State private var phase2 = false

    var body: some View {
        ZStack {
            // Base color
            (cs == .dark
             ? Color.black
             : Color(hex: "EEF4FF")
            )

            if cs != .dark {
                // Blob 1
                Circle()
                    .fill(Color(hex: "BEDAFF").opacity(0.8))
                    .frame(width: 380)
                    .blur(radius: 70)
                    .offset(x: phase1 ? -80 : 80, y: phase1 ? -160 : 80)
                    .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: phase1)

                // Blob 2
                Circle()
                    .fill(Color(hex: "A8C8FF").opacity(0.6))
                    .frame(width: 320)
                    .blur(radius: 60)
                    .offset(x: phase2 ? 100 : -120, y: phase2 ? 200 : -120)
                    .animation(.easeInOut(duration: 11).repeatForever(autoreverses: true), value: phase2)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            phase1 = true
            phase2 = true
        }
    }
}

// MARK: - Glass Text Field

struct BloomField: View {
    var placeholder: String
    var icon: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var autocap: UITextAutocapitalizationType = .sentences
    var isSecure: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(focused ? Color(hex: "4F8EF7") : .secondary)
                .frame(width: 24)
                .animation(.easeInOut(duration: 0.2), value: focused)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .focused($focused)
                } else {
                    TextField(placeholder, text: $text)
                        .focused($focused)
                        .keyboardType(keyboard)
                        .autocapitalization(autocap)
                }
            }
            .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    focused
                    ? Color(hex: "4F8EF7").opacity(0.6)
                    : Color.white.opacity(0.18),
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.2), value: focused)
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
