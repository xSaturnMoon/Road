import SwiftUI
import AudioToolbox

// MARK: - Settings View

struct SettingsView: View {
    @StateObject var auth = AuthManager.shared
    @StateObject var updateManager = UpdateManager.shared
    @State private var showingAuthModal = false
    @AppStorage("bloom_notification_sound") private var notificationSound: String = "Predefinito"
    
    let soundOptions: [(name: String, id: UInt32)] = [
        ("Predefinito", 1005),
        ("Tri-tono", 1005),
        ("Nota", 1012),
        ("Aurora", 1033),
        ("Basso", 1007)
    ]

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    if let user = auth.currentUser {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "4F8EF7"), Color(hex: "1A5FD4")],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 52, height: 52)
                                Text(user.name.prefix(1).uppercased())
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                auth.logout()
                            } label: {
                                Label("Esci", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.caption.bold())
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 6)
                    } else {
                        Button {
                            showingAuthModal = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(hex: "4F8EF7"), Color(hex: "1A5FD4")],
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Accedi o Registrati")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("I tuoi dati ti seguiranno ovunque")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Notifiche") {
                    Picker("Suono Promemoria", selection: $notificationSound) {
                        ForEach(soundOptions, id: \.name) { sound in
                            Text(sound.name).tag(sound.name)
                        }
                    }
                    .onChange(of: notificationSound) { _, newValue in
                        if let sound = soundOptions.first(where: { $0.name == newValue }) {
                            AudioServicesPlaySystemSound(sound.id)
                        }
                    }
                }

                Section {
                    Button {
                        updateManager.checkForUpdates(manual: true)
                    } label: {
                        HStack {
                            Label("Verifica Aggiornamenti", systemImage: "arrow.clockwise.circle")
                                .foregroundColor(.primary)
                            Spacer()
                            if updateManager.isChecking {
                                ProgressView()
                            } else if updateManager.isUpdatePending {
                                Text("In attesa di chiusura...")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("v\(updateManager.currentVersion)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .alert("Aggiornamento Disponibile", isPresented: $updateManager.isUpdateAvailable) {
                Button("Annulla", role: .cancel) { }
                Button("Installa al termine") { updateManager.prepareUpdate() }
            } message: {
                Text("È disponibile la versione \(updateManager.latestVersion). L'aggiornamento inizierà quando chiuderai l'app.")
            }
            .alert("Tutto pronto!", isPresented: $updateManager.isUpdatePending) {
                Button("Ho capito") { }
            } message: {
                Text("L'aggiornamento inizierà quando tornerai alla Home screen.")
            }
            .alert("App Aggiornata", isPresented: $updateManager.showUpToDateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Stai già utilizzando l'ultima versione di Bloom.")
            }
            .fullScreenCover(isPresented: $showingAuthModal) {
                AuthView(isPresented: $showingAuthModal)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                updateManager.triggerPendingUpdate()
            }
        }
    }
}

// MARK: - Auth View (Glassmorphism Redesign)

struct AuthView: View {
    @Binding var isPresented: Bool
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
             ? Color(hex: "090E1A")   // midnight navy
             : Color(hex: "EEF4FF")   // ice blue
            )

            // Blob 1 — deep blue
            Circle()
                .fill(
                    cs == .dark
                    ? Color(hex: "0E2A6E").opacity(0.7)
                    : Color(hex: "BEDAFF").opacity(0.8)
                )
                .frame(width: 380)
                .blur(radius: 70)
                .offset(x: phase1 ? -80 : 80, y: phase1 ? -160 : 80)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: phase1)

            // Blob 2 — indigo
            Circle()
                .fill(
                    cs == .dark
                    ? Color(hex: "1A3A8F").opacity(0.5)
                    : Color(hex: "A8C8FF").opacity(0.6)
                )
                .frame(width: 320)
                .blur(radius: 60)
                .offset(x: phase2 ? 100 : -120, y: phase2 ? 200 : -120)
                .animation(.easeInOut(duration: 11).repeatForever(autoreverses: true), value: phase2)
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
