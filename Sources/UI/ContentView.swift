import SwiftUI

enum Tab {
    case calendar
    case shopping
    case weather
    case settings
}

struct ContentView: View {
    @State private var selectedTab: Tab = .calendar
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarView()
                .tabItem {
                    Label("Calendario", systemImage: "calendar")
                }
                .tag(Tab.calendar)
            
            ShoppingView()
                .tabItem {
                    Label("Spesa", systemImage: "cart")
                }
                .tag(Tab.shopping)
            
            WeatherView()
                .tabItem {
                    Label("Meteo", systemImage: "cloud.sun")
                }
                .tag(Tab.weather)
            
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(.primary)
        .onAppear {
            setupAppleGlassAppearance()
        }
    }
    
    private func setupAppleGlassAppearance() {
        // TabBar Glass Effect
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // NavigationBar Glass Effect
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
}
