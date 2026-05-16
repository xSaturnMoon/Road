import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CalendarView()
                .tabItem {
                    Label("Calendario", systemImage: "calendar")
                }
            
            ShoppingView()
                .tabItem {
                    Label("Spesa", systemImage: "cart")
                }
            
            WeatherView()
                .tabItem {
                    Label("Meteo", systemImage: "cloud.sun")
                }
            
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape")
                }
        }
        .tint(.blue)
    }
}
