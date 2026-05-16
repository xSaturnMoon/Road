import SwiftUI

struct WeatherView: View {
    @StateObject var manager = WeatherManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main Background color based on weather
                backgroundColor
                    .ignoresSafeArea()
                
                if manager.isLoading && manager.weather == nil {
                    ProgressView("Caricamento...")
                        .tint(.white)
                } else if let weather = manager.weather {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 25) {
                            // Header Section
                            VStack(spacing: 8) {
                                Text(weather.city)
                                    .font(.system(size: 34, weight: .medium))
                                
                                Text("\(Int(weather.current.temp))°")
                                    .font(.system(size: 96, weight: .thin))
                                
                                Text(weather.current.description)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Text("M: \(Int(weather.daily.first?.tempMax ?? 0))°")
                                    Text("m: \(Int(weather.daily.first?.tempMin ?? 0))°")
                                }
                                .font(.headline)
                            }
                            .padding(.top, 20)
                            
                            // Hourly Section
                            VStack(alignment: .leading, spacing: 15) {
                                Label("PREVISIONI ORARIE", systemImage: "clock")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 20) {
                                        ForEach(weather.hourly) { hour in
                                            VStack(spacing: 10) {
                                                Text(hour.time, format: .dateTime.hour())
                                                    .font(.caption)
                                                
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
                            
                            // Daily Section
                            VStack(alignment: .leading, spacing: 15) {
                                Label("PREVISIONI A 7 GIORNI", systemImage: "calendar")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                
                                Divider()
                                
                                ForEach(weather.daily) { day in
                                    HStack {
                                        Text(day.date, format: .dateTime.weekday())
                                            .font(.headline)
                                            .frame(width: 50, alignment: .leading)
                                        
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
                                        
                                        // Simple Temp Bar
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
                                WeatherDetailCard(title: "UV INDEX", value: "\(Int(weather.current.uvIndex))", icon: "sun.max.fill", description: uvDescription(weather.current.uvIndex))
                                WeatherDetailCard(title: "VENTO", value: "\(Int(weather.current.windSpeed)) km/h", icon: "wind", description: "Direzione variabile")
                                WeatherDetailCard(title: "UMIDITÀ", value: "\(weather.current.humidity)%", icon: "humidity.fill", description: "Il punto di rugiada è \(Int(weather.current.temp - 2))°")
                                WeatherDetailCard(title: "VISIBILITÀ", value: "\(Int(weather.current.visibility)) km", icon: "eye.fill", description: "Cielo limpido")
                                WeatherDetailCard(title: "PRESSIONE", value: "\(Int(weather.current.pressure)) hPa", icon: "gauge.with.needle", description: "Stabile")
                                WeatherDetailCard(title: "PERCEPITA", value: "\(Int(weather.current.feelsLike))°", icon: "thermometer.medium", description: "Simile alla reale")
                            }
                            .padding(.horizontal)
                            
                            Spacer(minLength: 50)
                        }
                    }
                    .refreshable {
                        manager.requestLocation()
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("Meteo non disponibile")
                            .font(.headline)
                        Button("Riprova") {
                            manager.requestLocation()
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(Capsule())
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if manager.weather == nil {
                    manager.requestLocation()
                }
            }
        }
    }
    
    var backgroundColor: Color {
        guard let condition = manager.weather?.current.condition else { return Color(uiColor: .systemBackground) }
        switch condition {
        case "sunny": return Color.blue.opacity(0.8)
        case "rainy": return Color.gray.opacity(0.8)
        case "cloudy": return Color.cyan.opacity(0.6)
        case "thunder": return Color.indigo.opacity(0.8)
        default: return Color.blue.opacity(0.8)
        }
    }
    
    func uvDescription(_ val: Double) -> String {
        if val < 3 { return "Basso" }
        if val < 6 { return "Moderato" }
        return "Alto"
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
    let description: String
    
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
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
