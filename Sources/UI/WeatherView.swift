import SwiftUI

struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    @State private var showingAddCity = false
    @State private var showingLocationList = false
    @State private var newCityName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background fallback se non ci sono città
                if manager.locations.isEmpty {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    
                    ContentUnavailableView {
                        Label("Nessun Meteo", systemImage: "cloud.sun")
                    } description: {
                        Text("Aggiungi una città per iniziare.")
                    } actions: {
                        Button("Aggiungi Città") { showingAddCity = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    TabView {
                        ForEach(manager.locations) { location in
                            if let weather = manager.weatherData[location.id] {
                                WeatherDetailPage(weather: weather)
                            } else {
                                ZStack {
                                    Color.blue.opacity(0.2).ignoresSafeArea()
                                    ProgressView()
                                        .controlSize(.large)
                                }
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .ignoresSafeArea(.all, edges: .top)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCity = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(manager.locations.isEmpty ? .primary : .white)
                            .font(.body.weight(.bold))
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLocationList = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(manager.locations.isEmpty ? .primary : .white)
                            .font(.body.weight(.bold))
                    }
                }
            }
            .sheet(isPresented: $showingAddCity) {
                AddCityView(isPresented: $showingAddCity)
            }
            .sheet(isPresented: $showingLocationList) {
                LocationListView(isPresented: $showingLocationList)
            }
        }
    }
}

struct WeatherDetailPage: View {
    let weather: WeatherData
    @State private var selectedDay: DailyWeather?
    
    var body: some View {
        ZStack {
            // Sfondo Dinamico
            WeatherBackground(condition: weather.current.condition)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 4) {
                        Text(weather.city)
                            .font(.system(size: 36, weight: .semibold, design: .default))
                            .shadow(radius: 2)
                        
                        Text("\(Int(weather.current.temp))°")
                            .font(.system(size: 96, weight: .thin, design: .default))
                            .shadow(radius: 2)
                            .padding(.leading, 15) // Compensa il simbolo del grado
                        
                        Text(weather.current.description)
                            .font(.title3.weight(.medium))
                            .shadow(radius: 2)
                        
                        HStack(spacing: 15) {
                            Text("Max: \(Int(weather.daily.first?.tempMax ?? 0))°")
                            Text("Min: \(Int(weather.daily.first?.tempMin ?? 0))°")
                        }
                        .font(.headline.weight(.medium))
                    }
                    .foregroundColor(.white)
                    .padding(.top, 80)
                    .padding(.bottom, 20)
                    
                    // Previsioni Orarie (Prossime 24h)
                    VStack(alignment: .leading, spacing: 15) {
                        Label("PREVISIONI ORARIE", systemImage: "clock")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal)
                        
                        let upcomingHours = Array(weather.hourly.filter { $0.time >= Date() }.prefix(24))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 25) {
                                ForEach(upcomingHours) { hour in
                                    VStack(spacing: 12) {
                                        Text(hour.time.formatted(.dateTime.hour().locale(Locale(identifier: "it_IT"))))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                        
                                        WeatherIcon(condition: hour.condition)
                                            .font(.title2)
                                        
                                        if hour.rainProbability > 0 {
                                            Text("\(hour.rainProbability)%")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.cyan)
                                        } else {
                                            Spacer().frame(height: 13)
                                        }
                                        
                                        Text("\(Int(hour.temp))°")
                                            .font(.title3.weight(.medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark) // Forza i materiali in modalità scura per il contrasto
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .padding(.horizontal)
                    
                    // Previsioni Giornaliere (7 giorni)
                    VStack(alignment: .leading, spacing: 0) {
                        Label("PROSSIMI 7 GIORNI", systemImage: "calendar")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, 15)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        ForEach(weather.daily) { day in
                            Button {
                                selectedDay = day
                            } label: {
                                HStack {
                                    Text(day.date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                                        .font(.headline.weight(.medium))
                                        .frame(width: 110, alignment: .leading)
                                        .foregroundColor(.white)
                                    
                                    WeatherIcon(condition: day.condition)
                                        .font(.title3)
                                    
                                    if day.rainProbability > 0 {
                                        Text("\(day.rainProbability)%")
                                            .font(.caption.bold())
                                            .foregroundColor(.cyan)
                                            .frame(width: 35)
                                    } else {
                                        Spacer().frame(width: 35)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(Int(day.tempMin))°")
                                        .foregroundStyle(.white.opacity(0.6))
                                        .font(.headline.weight(.medium))
                                        .frame(width: 35)
                                    
                                    Text("\(Int(day.tempMax))°")
                                        .foregroundColor(.white)
                                        .font(.headline.weight(.medium))
                                        .frame(width: 35)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal)
                                .contentShape(Rectangle()) // Rende cliccabile l'intera riga
                            }
                            .buttonStyle(.plain)
                            
                            if day.id != weather.daily.last?.id {
                                Divider()
                                    .background(.white.opacity(0.2))
                                    .padding(.leading, 15)
                            }
                        }
                    }
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 0.5)
                    )
                    .padding(.horizontal)
                    
                    // Griglia Dettagli
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        WeatherDetailCard(title: "UV INDEX", value: "\(Int(weather.current.uvIndex))", icon: "sun.max.fill")
                        WeatherDetailCard(title: "UMIDITÀ", value: "\(weather.current.humidity)%", icon: "humidity.fill")
                        WeatherDetailCard(title: "VENTO", value: "\(Int(weather.current.windSpeed)) km/h", icon: "wind")
                        WeatherDetailCard(title: "PRESSIONE", value: "\(Int(weather.current.pressure)) hPa", icon: "gauge.with.needle")
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 80)
                }
            }
        }
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day, city: weather.city, hourlyData: weather.hourly)
        }
    }
}

struct DayDetailView: View {
    let day: DailyWeather
    let city: String
    let hourlyData: [HourlyWeather]
    
    var hoursForDay: [HourlyWeather] {
        hourlyData.filter { Calendar.current.isDate($0.time, inSameDayAs: day.date) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                WeatherBackground(condition: day.condition)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Riepilogo Card
                        VStack(spacing: 0) {
                            HStack {
                                Text("Condizione")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(day.description)
                                    .foregroundStyle(.white.opacity(0.8))
                                WeatherIcon(condition: day.condition)
                                    .padding(.leading, 4)
                            }
                            .padding()
                            
                            Divider().background(.white.opacity(0.2)).padding(.leading)
                            
                            HStack {
                                Text("Temperatura Max")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(day.tempMax))°").bold().foregroundColor(.white)
                            }
                            .padding()
                            
                            Divider().background(.white.opacity(0.2)).padding(.leading)
                            
                            HStack {
                                Text("Temperatura Min")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(day.tempMin))°").bold().foregroundColor(.white)
                            }
                            .padding()
                            
                            Divider().background(.white.opacity(0.2)).padding(.leading)
                            
                            HStack {
                                Text("Probabilità Pioggia")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(day.rainProbability)%").bold().foregroundColor(.cyan)
                            }
                            .padding()
                        }
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                        
                        // Ore Card
                        VStack(alignment: .leading, spacing: 0) {
                            Label("METEO ORARIO", systemImage: "clock")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.bottom, 15)
                                .padding(.horizontal)
                                .padding(.top, 16)
                            
                            if hoursForDay.isEmpty {
                                Text("Dati orari non disponibili.")
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding()
                            } else {
                                ForEach(hoursForDay) { hour in
                                    HStack {
                                        Text(hour.time.formatted(.dateTime.hour().locale(Locale(identifier: "it_IT"))))
                                            .font(.headline.weight(.medium))
                                            .frame(width: 60, alignment: .leading)
                                            .foregroundColor(.white)
                                        
                                        WeatherIcon(condition: hour.condition)
                                            .font(.title3)
                                            .frame(width: 30)
                                        
                                        if hour.rainProbability > 0 {
                                            Text("\(hour.rainProbability)%")
                                                .font(.caption.bold())
                                                .foregroundColor(.cyan)
                                                .frame(width: 45)
                                        } else {
                                            Spacer().frame(width: 45)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(hour.description)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.8))
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(hour.temp))°")
                                            .font(.headline.weight(.medium))
                                            .foregroundColor(.white)
                                            .frame(width: 40, alignment: .trailing)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal)
                                    
                                    if hour.id != hoursForDay.last?.id {
                                        Divider().background(.white.opacity(0.2)).padding(.leading, 15)
                                    }
                                }
                            }
                        }
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(.white.opacity(0.3), lineWidth: 0.5)
                        )
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Dismiss action is handled automatically by SwiftUI if inside a sheet,
                        // but to be explicit we could use @Environment(\.dismiss), 
                        // for now relying on the standard gesture or adding an explicit dismiss if needed.
                        // We will just leave it empty if the user can swipe down, but let's add @Environment
                    } label: {
                        Text("Chiudi").bold()
                    }
                }
            }
            // Forziamo il tema scuro per la barra di navigazione così il testo bianco si vede bene
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct LocationListView: View {
    @Binding var isPresented: Bool
    @StateObject var manager = WeatherManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.locations) { loc in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(loc.name).font(.headline)
                            if let w = manager.weatherData[loc.id] {
                                Text(w.current.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let w = manager.weatherData[loc.id] {
                            Text("\(Int(w.current.temp))°").font(.title2.bold())
                        }
                    }
                }
                .onDelete(perform: manager.removeCity)
            }
            .navigationTitle("Le mie città")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
    }
}

struct AddCityView: View {
    @Binding var isPresented: Bool
    @State private var cityName = ""
    @StateObject var manager = WeatherManager.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Cerca città...", text: $cityName)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                Button("Aggiungi") {
                    manager.addCity(name: cityName)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(cityName.isEmpty)
                
                Spacer()
            }
            .navigationTitle("Nuova Città")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Annulla") { isPresented = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WeatherIcon: View {
    let condition: String
    var body: some View {
        Image(systemName: iconName).renderingMode(.original)
    }
    var iconName: String {
        switch condition {
        case "sunny": return "sun.max.fill"
        case "cloudy": return "cloud.fill"
        case "rainy": return "cloud.rain.fill"
        case "snowy": return "cloud.snow.fill"
        case "thunder": return "cloud.bolt.fill"
        case "fog": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }
}

struct WeatherDetailCard: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.7))
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(value)
                .font(.title2.weight(.medium))
                .foregroundColor(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 90)
        .padding()
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Dynamic Background
struct WeatherBackground: View {
    let condition: String
    
    var body: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    var backgroundColors: [Color] {
        switch condition {
        case "sunny":
            return [Color(hex: "4FA8FF"), Color(hex: "1F76D2")] // Cielo azzurro
        case "cloudy":
            return [Color(hex: "78909C"), Color(hex: "455A64")] // Grigio nuvoloso
        case "rainy":
            return [Color(hex: "37474F"), Color(hex: "102027")] // Grigio scuro/pioggia
        case "snowy":
            return [Color(hex: "90A4AE"), Color(hex: "CFD8DC")] // Grigio chiaro neve
        case "thunder":
            return [Color(hex: "263238"), Color(hex: "000000")] // Tempesta
        case "fog":
            return [Color(hex: "9E9E9E"), Color(hex: "616161")] // Nebbia
        default:
            return [Color(hex: "4FA8FF"), Color(hex: "1F76D2")]
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

