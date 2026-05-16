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
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
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
                                    Text("Crea un Account")
                                        .font(.headline)
                                    Text("Sincronizza i tuoi dati nel cloud")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Appearance Section
                Section("Aspetto") {
                    Toggle(isOn: $useSystemTheme) {
                        Label("Usa Tema di Sistema", systemImage: "iphone")
                    }
                    
                    if !useSystemTheme {
                        Toggle(isOn: $isDarkMode) {
                            Label("Modalità Scura", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
                        }
                    }
                }
                
                // General Section
                Section("Generali") {
                    NavigationLink {
                        Text("Notifiche")
                    } label: {
                        Label("Notifiche", systemImage: "bell.badge.fill")
                    }
                    
                    NavigationLink {
                        Text("Privacy e Sicurezza")
                    } label: {
                        Label("Privacy", systemImage: "hand.raised.fill")
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
                            } else {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("v\(updateManager.currentVersion)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(Bundle.main.bundleIdentifier ?? "N/D")
                                        .font(.system(size: 8, weight: .light, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/xSaturnMoon/Bloom")!) {
                        Label("Sito Web Bloom", systemImage: "safari")
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .alert("Aggiornamento Disponibile", isPresented: $updateManager.isUpdateAvailable) {
                Button("Annulla", role: .cancel) { }
                Button("Scarica e Installa") {
                    if let url = URL(string: updateManager.downloadURL) {
                        UIApplication.shared.open(url)
                        // Forza la chiusura dopo 1 secondo per permettere l'avvio del download
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            exit(0)
                        }
                    }
                }
            } message: {
                Text("È disponibile una nuova versione di Bloom (\(updateManager.latestVersion)). L'app si chiuderà per completare l'installazione.")
            }
            .alert("App Aggiornata", isPresented: $updateManager.showUpToDateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Stai già utilizzando l'ultima versione di Bloom.")
            }
            .sheet(isPresented: $showingAuthModal) {
                AuthView(isPresented: $showingAuthModal)
            }
        }
    }
}

struct AuthView: View {
    @Binding var isPresented: Bool
    @State private var isLogin = false
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @ObservedObject var auth = AuthManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                VStack(spacing: 12) {
                    Image(systemName: "aqi.medium")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding()
                        .background(.blue.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text(isLogin ? "Bentornato su Bloom" : "Crea Account Bloom")
                        .font(.title.bold())
                    
                    Text("I tuoi dati saranno al sicuro e sincronizzati in tempo reale su ogni dispositivo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 30)
                
                VStack(spacing: 15) {
                    if !isLogin {
                        TextField("Nome", text: $name)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    TextField("Email", text: $email)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                Button {
                    if isLogin {
                        auth.login(email: email)
                    } else {
                        auth.signUp(email: email, name: name)
                    }
                    isPresented = false
                } label: {
                    Text(isLogin ? "Accedi" : "Registrati")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty))
                
                Button {
                    withAnimation {
                        isLogin.toggle()
                    }
                } label: {
                    Text(isLogin ? "Non hai un account? Registrati" : "Hai già un account? Accedi")
                        .font(.subheadline)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
            }
        }
    }
}
