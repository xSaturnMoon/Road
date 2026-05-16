import SwiftUI

struct ContentView: View {
    @StateObject var appManager = AppManager.shared
    @StateObject var updateManager = UpdateManager.shared
    
    var body: some View {
        ZStack {
            TabView(selection: $appManager.selectedTab) {
                CalendarView()
                    .tabItem { Label("Calendario", systemImage: "calendar") }
                    .tag(0)
                
                ShoppingView()
                    .tabItem { Label("Spesa", systemImage: "cart") }
                    .tag(1)
                
                WeatherView()
                    .tabItem { Label("Meteo", systemImage: "cloud.sun") }
                    .tag(2)
                
                SettingsView()
                    .tabItem { Label("Impostazioni", systemImage: "gear") }
                    .tag(3)
            }
            .tint(.blue)
            
            // Update Overlay
            if updateManager.isUpdateAvailable {
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Aggiornamento Disponibile! (\(updateManager.latestVersion))")
                                .font(.headline)
                            Text("Tocca per scaricare l'ultima versione.")
                                .font(.caption)
                        }
                        Spacer()
                        Button("Scarica") {
                            if let url = URL(string: updateManager.downloadURL) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(Capsule())
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(radius: 10)
                    .padding()
                    .padding(.bottom, 60)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onAppear {
            updateManager.checkForUpdates()
        }
    }
}
