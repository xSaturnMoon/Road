import SwiftUI

struct ContentView: View {
    @State private var showingAuth = false
    @State private var hasCheckedAuth = false

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
        }
        .fullScreenCover(isPresented: $showingAuth) {
            AuthView(isPresented: $showingAuth, isOptional: false)
                .interactiveDismissDisabled() // Prevent swipe to dismiss
        }
        .onAppear {
            if !hasCheckedAuth {
                hasCheckedAuth = true
                if AuthManager.shared.currentUser == nil {
                    showingAuth = true
                }
            }
        }
        .onChange(of: AuthManager.shared.currentUser?.id) { _, newId in
            if newId == nil {
                showingAuth = true
            } else {
                showingAuth = false
            }
        }
    }
}
