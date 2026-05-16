import SwiftUI

struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    @State private var showingAddCity = false
    @State private var showingLocationList = false
    @State private var newCityName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                if manager.locations.isEmpty {
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
                                ProgressView()
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            }
            .navigationTitle("Meteo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCity = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLocationList = true
                    } label: {
                        Image(systemName: "list.bullet")
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Text(weather.city)
                        .font(.system(size: 34, weight: .medium))
                    
                    Text("\(Int(weather.current.temp))°")
                        .font(.system(size: 100, weight: .thin))
                    
                    Text(weather.current.description)
                        .font(.title2.bold())
                    
                    HStack(spacing: 15) {
                        Text("Max: \(Int(weather.daily.first?.tempMax ?? 0))°")
                        Text("Min: \(Int(weather.daily.first?.tempMin ?? 0))°")
                    }
                    .font(.headline)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Hourly Forecast with Rain Prob
                VStack(alignment: .leading, spacing: 15) {
                    Label("PREVISIONI ORARIE", systemImage: "clock")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 25) {
                            ForEach(weather.hourly) { hour in
                                VStack(spacing: 8) {
                                    Text(hour.time.formatted(.dateTime.hour().locale(Locale(identifier: "it_IT"))))
                                        .font(.caption.bold())
                                    
                                    WeatherIcon(condition: hour.condition)
                                        .font(.title3)
                                    
                                    if hour.rainProbability > 0 {
                                        Text("\(hour.rainProbability)%")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.blue)
                                    } else {
                                        Spacer().frame(height: 12)
                                    }
                                    
                                    Text("\(Int(hour.temp))°")
                                        .font(.headline)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .padding(.horizontal)
                
                // Daily Forecast
                VStack(alignment: .leading, spacing: 0) {
                    Label("PROSSIMI 7 GIORNI", systemImage: "calendar")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 15)
                        .padding(.horizontal)
                    
                    ForEach(weather.daily) { day in
                        Button {
                            selectedDay = day
                        } label: {
                            HStack {
                                Text(day.date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "it_IT"))).capitalized)
                                    .font(.headline)
                                    .frame(width: 110, alignment: .leading)
                                
                                WeatherIcon(condition: day.condition)
                                    .font(.title3)
                                
                                if day.rainProbability > 0 {
                                    Text("\(day.rainProbability)%")
                                        .font(.caption2.bold())
                                        .foregroundColor(.blue)
                                        .frame(width: 35)
                                } else {
                                    Spacer().frame(width: 35)
                                }
                                
                                Spacer()
                                
                                Text("\(Int(day.tempMin))°")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 35)
                                
                                Text("\(Int(day.tempMax))°")
                                    .frame(width: 35)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color.primary.opacity(0.03))
                        }
                        .buttonStyle(.plain)
                        
                        if day.id != weather.daily.last?.id {
                            Divider().padding(.leading, 120)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .padding(.horizontal)
                
                // Detail Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    WeatherDetailCard(title: "UV INDEX", value: "\(Int(weather.current.uvIndex))", icon: "sun.max.fill")
                    WeatherDetailCard(title: "UMIDITÀ", value: "\(weather.current.humidity)%", icon: "humidity.fill")
                    WeatherDetailCard(title: "VENTO", value: "\(Int(weather.current.windSpeed)) km/h", icon: "wind")
                    WeatherDetailCard(title: "PRESSIONE", value: "\(Int(weather.current.pressure)) hPa", icon: "gauge.with.needle")
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day, city: weather.city)
        }
    }
}

struct DayDetailView: View {
    let day: DailyWeather
    let city: String
    
    var body: some View {
        NavigationStack {
            List {
                Section("Riepilogo") {
                    HStack {
                        Text("Temperatura Massima")
                        Spacer()
                        Text("\(Int(day.tempMax))°").bold()
                    }
                    HStack {
                        Text("Temperatura Minima")
                        Spacer()
                        Text("\(Int(day.tempMin))°").bold()
                    }
                    HStack {
                        Text("Probabilità Pioggia")
                        Spacer()
                        Text("\(day.rainProbability)%").bold().foregroundColor(.blue)
                    }
                }
                
                Section("Condizione") {
                    HStack {
                        WeatherIcon(condition: day.condition).font(.title)
                        Text(day.condition.capitalized)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle(day.date.formatted(.dateTime.day().month().weekday(.wide).locale(Locale(identifier: "it_IT"))))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Chiudi") { }
                }
            }
        }
        .presentationDetents([.medium])
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
            HStack { Image(systemName: icon).foregroundStyle(.secondary); Text(title).font(.caption.bold()).foregroundStyle(.secondary) }
            Text(value).font(.title3.bold())
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading).frame(height: 80).padding()
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
