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
        }
        .alert("Aggiornamento Disponibile", isPresented: $updateManager.isUpdateAvailable) {
            Button("Scarica Ora") {
                if let url = URL(string: updateManager.downloadURL) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Più Tardi", role: .cancel) { }
        } message: {
            Text("È disponibile la versione \(updateManager.latestVersion). Vuoi installarla ora per ricevere le ultime novità?")
        }
        .onAppear {
            updateManager.checkForUpdates()
        }
    }
}
