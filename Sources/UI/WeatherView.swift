import SwiftUI

struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    @State private var showingAddCity = false
    @State private var newCityName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // System Background for a cleaner look
                Color(uiColor: .systemBackground).ignoresSafeArea()
                
                if manager.locations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "location.slash.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Nessuna città aggiunta")
                            .font(.headline)
                        Button("Aggiungi Città") {
                            showingAddCity = true
                        }
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
                        Image(systemName: "plus.magnifyingglass")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if !manager.locations.isEmpty {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddCity) {
                NavigationStack {
                    VStack(spacing: 20) {
                        TextField("Cerca città (es. Roma, Milano)", text: $newCityName)
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        
                        Button("Aggiungi") {
                            manager.addCity(name: newCityName)
                            newCityName = ""
                            showingAddCity = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newCityName.isEmpty)
                        
                        Spacer()
                    }
                    .navigationTitle("Aggiungi Città")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Chiudi") { showingAddCity = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

struct WeatherDetailPage: View {
    let weather: WeatherData
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 8) {
                    Text(weather.city)
                        .font(.system(size: 34, weight: .medium))
                    
                    Text("\(Int(weather.current.temp))°")
                        .font(.system(size: 96, weight: .thin))
                    
                    Text(weather.current.description)
                        .font(.title3.bold())
                    
                    HStack {
                        Text("MAX: \(Int(weather.daily.first?.tempMax ?? 0))°")
                        Text("MIN: \(Int(weather.daily.first?.tempMin ?? 0))°")
                    }
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                
                // Hourly
                VStack(alignment: .leading, spacing: 15) {
                    Text("PREVISIONI ORARIE")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(weather.hourly) { hour in
                                VStack(spacing: 10) {
                                    Text(hour.time.formatted(.dateTime.hour()))
                                        .font(.caption.bold())
                                    
                                    WeatherIcon(condition: hour.condition)
                                        .font(.title2)
                                    
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
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
                
                // Daily
                VStack(alignment: .leading, spacing: 15) {
                    Text("PROSSIMI 7 GIORNI")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    ForEach(weather.daily) { day in
                        HStack {
                            Text(day.date.formatted(.dateTime.weekday(.wide)).capitalized)
                                .font(.headline)
                                .frame(width: 100, alignment: .leading)
                            
                            Spacer()
                            
                            WeatherIcon(condition: day.condition)
                                .font(.title3)
                            
                            if day.rainProbability > 0 {
                                Text("\(day.rainProbability)%")
                                    .font(.caption2.bold())
                                    .foregroundColor(.blue)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(day.tempMin))°")
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                            
                            Capsule()
                                .fill(LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 60, height: 4)
                            
                            Text("\(Int(day.tempMax))°")
                                .frame(width: 30)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
                
                // Details Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    WeatherDetailCard(title: "UV INDEX", value: "\(Int(weather.current.uvIndex))", icon: "sun.max.fill")
                    WeatherDetailCard(title: "VENTO", value: "\(Int(weather.current.windSpeed)) km/h", icon: "wind")
                    WeatherDetailCard(title: "UMIDITÀ", value: "\(weather.current.humidity)%", icon: "humidity.fill")
                    WeatherDetailCard(title: "VISIBILITÀ", value: "\(Int(weather.current.visibility)) km", icon: "eye.fill")
                    WeatherDetailCard(title: "PRESSIONE", value: "\(Int(weather.current.pressure)) hPa", icon: "gauge.with.needle")
                    WeatherDetailCard(title: "PERCEPITA", value: "\(Int(weather.current.feelsLike))°", icon: "thermometer.medium")
                }
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
    }
}

struct WeatherIcon: View {
    let condition: String
    
    var body: some View {
        Image(systemName: iconName)
            .renderingMode(.original)
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
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title2.bold())
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
