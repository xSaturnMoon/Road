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
            .sheet(isPresented: $showingAuthModal) {
                AuthView(isPresented: $showingAuthModal)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                updateManager.triggerPendingUpdate()
            }
        }
    }
}

struct AuthView: View {
    @Binding var isPresented: Bool
    @State private var isLogin = true
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @StateObject var auth = AuthManager.shared
    @State private var animateItems = false
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3), .cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
                .blur(radius: 50)
            
            VStack(spacing: 30) {
                VStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: isLogin ? "lock.shield.fill" : "person.badge.plus.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    }
                    .scaleEffect(animateItems ? 1 : 0.5)
                    .opacity(animateItems ? 1 : 0)
                    
                    Text(isLogin ? "Bentornato" : "Nuovo Account")
                        .font(.largeTitle.bold())
                }
                
                VStack(spacing: 20) {
                    if !isLogin {
                        GlassTextField(placeholder: "Nome", text: $name, icon: "person.fill")
                    }
                    GlassTextField(placeholder: "Email", text: $email, icon: "envelope.fill")
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    GlassSecureField(placeholder: "Password", text: $password, icon: "key.fill")
                }
                .padding(.horizontal)
                
                if let error = auth.authError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Button {
                    if isLogin {
                        auth.login(email: email, password: password)
                    } else {
                        auth.signUp(email: email, name: name, password: password)
                    }
                } label: {
                    HStack {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isLogin ? "Accedi" : "Crea Account")
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right.circle.fill")
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal)
                .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
                
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        isLogin.toggle()
                        auth.authError = nil
                    }
                } label: {
                    Text(isLogin ? "Non hai un account? Registrati ora" : "Hai già un account? Accedi")
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .padding(.top, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateItems = true
            }
        }
        .onChange(of: auth.currentUser?.id) { _ in
            if auth.currentUser != nil { isPresented = false }
        }
    }
}

struct GlassTextField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 30)
            TextField(placeholder, text: $text)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

struct GlassSecureField: View {
    var placeholder: String
    @Binding var text: String
    var icon: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 30)
            SecureField(placeholder, text: $text)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 1))
    }
}
