import SwiftUI

struct SettingsView: View {
    @StateObject var auth = AuthManager.shared
    @StateObject var updateManager = UpdateManager.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("useSystemTheme") private var useSystemTheme = true
    @State private var showingAuthModal = false
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    if let user = auth.currentUser {
                        HStack(spacing: 15) {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(user.name.prefix(1).uppercased())
                                        .font(.title.bold())
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                auth.logout()
                            } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            showingAuthModal = true
                        } label: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("Accedi o Registrati")
                                        .font(.headline)
                                    Text("Per non perdere mai i tuoi dati")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Info Section
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
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("v\(updateManager.currentVersion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .alert("Aggiornamento Disponibile", isPresented: $updateManager.isUpdateAvailable) {
                Button("Annulla", role: .cancel) { }
                Button("Installa al termine") {
                    updateManager.prepareUpdate()
                }
            } message: {
                Text("È disponibile la versione \(updateManager.latestVersion). L'aggiornamento inizierà automaticamente quando chiuderai l'app.")
            }
            .alert("Tutto pronto!", isPresented: $updateManager.isUpdatePending) {
                Button("Ho capito") { }
            } message: {
                Text("L'aggiornamento inizierà quando tornerai alla Home screen. A presto!")
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

// MARK: - Auth View Overhaul

struct AuthView: View {
    @Binding var isPresented: Bool
    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @StateObject var auth = AuthManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var animateBg = false
    @State private var animateForm = false
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // MARK: - Dynamic Living Background
            MeshBackground(animate: animateBg)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Close Button
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        // Icon Section
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.1), radius: 10)
                            
                            Image(systemName: isLogin ? "lock.shield.fill" : "person.badge.plus.fill")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .offset(y: animateForm ? 0 : -20)
                        .opacity(animateForm ? 1 : 0)
                        
                        VStack(spacing: 8) {
                            Text(isLogin ? "Bentornato" : "Crea un Account")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                            
                            Text(isLogin ? "Inserisci le tue credenziali per accedere." : "Inizia il tuo viaggio con Bloom.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .offset(y: animateForm ? 0 : 20)
                        .opacity(animateForm ? 1 : 0)
                        
                        // MARK: - Form
                        VStack(spacing: 18) {
                            if !isLogin {
                                GlassInput(placeholder: "Nome Completo", text: $name, icon: "person.fill")
                                    .transition(.asymmetric(insertion: .push(from: .top), removal: .move(edge: .top)).combined(with: .opacity))
                            }
                            
                            GlassInput(placeholder: "Email", text: $email, icon: "envelope.fill")
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            GlassInput(placeholder: "Password", text: $password, icon: "key.fill", isSecure: true)
                        }
                        .padding(.horizontal)
                        .offset(x: shakeOffset)
                        .offset(y: animateForm ? 0 : 30)
                        .opacity(animateForm ? 1 : 0)
                        
                        if let error = auth.authError {
                            Text(error)
                                .font(.footnote.bold())
                                .foregroundColor(.red)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(.red.opacity(0.1)))
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // MARK: - Action Button
                        Button {
                            triggerAuth()
                        } label: {
                            HStack {
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isLogin ? "Accedi" : "Registrati Ora")
                                        .font(.headline.bold())
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.bold())
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                LinearGradient(colors: [.blue, .blue.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .blue.opacity(0.3), radius: 15, y: 8)
                        }
                        .padding(.horizontal)
                        .scaleEffect(auth.isLoading ? 0.95 : 1.0)
                        .offset(y: animateForm ? 0 : 40)
                        .opacity(animateForm ? 1 : 0)
                        
                        // Footer Toggle
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                isLogin.toggle()
                                auth.authError = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isLogin ? "Nuovo su Bloom?" : "Hai già un account?")
                                    .foregroundStyle(.secondary)
                                Text(isLogin ? "Registrati" : "Accedi")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            .font(.subheadline)
                        }
                        .padding(.top, 10)
                        .offset(y: animateForm ? 0 : 50)
                        .opacity(animateForm ? 1 : 0)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .preferredColorScheme(nil) // Auto-adapt
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: true)) {
                animateBg.toggle()
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                animateForm = true
            }
        }
        .onChange(of: auth.authError) { error in
            if error != nil {
                performShake()
            }
        }
        .onChange(of: auth.currentUser?.id) { _ in
            if auth.currentUser != nil { 
                withAnimation { isPresented = false }
            }
        }
    }
    
    private func triggerAuth() {
        if isLogin {
            auth.login(email: email, password: password)
        } else {
            auth.signUp(email: email, name: name, password: password)
        }
    }
    
    private func performShake() {
        for i in 0...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                    shakeOffset = (i == 6) ? 0 : (i % 2 == 0 ? 10 : -10)
                }
            }
        }
    }
}

// MARK: - Components

struct MeshBackground: View {
    @State private var move1 = false
    @State private var move2 = false
    @Environment(\.colorScheme) var colorScheme
    let animate: Bool
    
    var body: some View {
        ZStack {
            Color(colorScheme == .dark ? .black : .white)
            
            // Sphere 1
            Circle()
                .fill(colorScheme == .dark ? Color.blue.opacity(0.4) : Color.blue.opacity(0.2))
                .frame(width: 400)
                .offset(x: move1 ? -100 : 100, y: move1 ? -200 : 200)
                .blur(radius: 80)
            
            // Sphere 2
            Circle()
                .fill(colorScheme == .dark ? Color.purple.opacity(0.4) : Color.purple.opacity(0.2))
                .frame(width: 450)
                .offset(x: move2 ? 150 : -150, y: move2 ? 250 : -250)
                .blur(radius: 90)
            
            Rectangle()
                .fill(.ultraThinMaterial)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                move1.toggle()
            }
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                move2.toggle()
            }
        }
    }
}

struct GlassInput: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    var isSecure: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isFocused ? .blue : .secondary)
                .frame(width: 30)
                .scaleEffect(isFocused ? 1.1 : 1.0)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .focused($isFocused)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(isFocused ? 0.05 : 0), radius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isFocused ? Color.blue.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1.5)
        )
        .animation(.spring(response: 0.3), value: isFocused)
    }
}
