import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AppsView()
                .tabItem {
                    Label("Apps", systemImage: "square.grid.2x2.fill")
                }
            
            InstallView()
                .tabItem {
                    Label("Installa", systemImage: "plus.circle.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}
