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
        ZStack(alignment: .bottom) {
            // SFONDO GRIGIO SCURO (Migliora il contrasto del vetro)
            Color(red: 0.05, green: 0.05, blue: 0.07)
                .ignoresSafeArea()
            
            // COLOR BLOBS ANIMATI (Fondamentali per vedere l'effetto vetro)
            Group {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 400)
                    .blur(radius: 100)
                    .offset(x: -150, y: 100)
                    .opacity(0.4)
                
                Circle()
                    .fill(Color.purple)
                    .frame(width: 400)
                    .blur(radius: 100)
                    .offset(x: 150, y: -100)
                    .opacity(0.4)
            }
            
            // CONTENUTO PRINCIPALE
            Group {
                switch selectedTab {
                case .calendar:
                    CalendarView()
                case .shopping:
                    ShoppingView()
                case .weather:
                    WeatherView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // --- TAB BAR FLUTTUANTE (SIDEBAR IN BASSO TRUE GLASS) ---
            HStack(spacing: 30) {
                TabButton(icon: "calendar", label: "Calendario", isSelected: selectedTab == .calendar) {
                    selectedTab = .calendar
                }
                TabButton(icon: "cart", label: "Spesa", isSelected: selectedTab == .shopping) {
                    selectedTab = .shopping
                }
                TabButton(icon: "cloud.sun", label: "Meteo", isSelected: selectedTab == .weather) {
                    selectedTab = .weather
                }
                TabButton(icon: "gearshape", label: "Impo...", isSelected: selectedTab == .settings) {
                    selectedTab = .settings
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 30)
            .background(
                VisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
                    .clipShape(Capsule())
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// Wrapping UIVisualEffectView for the official Apple Glass effect
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        return view
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(label)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(isSelected ? .blue : .white.opacity(0.5))
            .shadow(color: isSelected ? .blue.opacity(0.5) : .clear, radius: 10)
        }
        .buttonStyle(.plain)
    }
}
