import Foundation
import CoreLocation
import Combine

struct WeatherData: Identifiable, Codable {
    var id = UUID()
    var city: String
    var current: CurrentWeather
    var hourly: [HourlyWeather]
    var daily: [DailyWeather]
}

struct CurrentWeather: Codable {
    var temp: Double
    var description: String
    var condition: String // e.g. "sunny", "cloudy", "rainy"
    var humidity: Int
    var windSpeed: Double
    var uvIndex: Double
    var visibility: Double
    var pressure: Double
    var feelsLike: Double
}

struct HourlyWeather: Identifiable, Codable {
    var id = UUID()
    var time: Date
    var temp: Double
    var condition: String
}

struct DailyWeather: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var tempMin: Double
    var tempMax: Double
    var condition: String
    var rainProbability: Int
}

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var error: String?
    
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    
    func requestLocation() {
        isLoading = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        fetchWeather(for: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = "Errore localizzazione: \(error.localizedDescription)"
        self.isLoading = false
    }
    
    func fetchWeather(for location: CLLocation) {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        // Open-Meteo API (No key required, highly accurate)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,pressure_msl,surface_pressure,wind_speed_10m,uv_index,visibility&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto"
        
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: OpenMeteoResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isLoading = false
                if case .failure(let err) = completion {
                    self.error = "Errore dati meteo: \(err.localizedDescription)"
                }
            } receiveValue: { response in
                self.weather = self.parseResponse(response, location: location)
            }
            .store(in: &cancellables)
    }
    
    private func parseResponse(_ res: OpenMeteoResponse, location: CLLocation) -> WeatherData {
        // Reverse geocoding to get city name
        let city = "Posizione Attuale" // Default
        
        let current = CurrentWeather(
            temp: res.current.temperature_2m,
            description: weatherCodeToText(res.current.weather_code),
            condition: weatherCodeToCondition(res.current.weather_code),
            humidity: res.current.relative_humidity_2m,
            windSpeed: res.current.wind_speed_10m,
            uvIndex: res.current.uv_index,
            visibility: res.current.visibility / 1000.0, // Convert to km
            pressure: res.current.pressure_msl,
            feelsLike: res.current.apparent_temperature
        )
        
        var hourly: [HourlyWeather] = []
        for i in 0..<24 {
            let time = Date().addingTimeInterval(TimeInterval(i * 3600))
            hourly.append(HourlyWeather(time: time, temp: res.hourly.temperature_2m[i], condition: weatherCodeToCondition(res.hourly.weather_code[i])))
        }
        
        var daily: [DailyWeather] = []
        for i in 0..<7 {
            let date = Date().addingTimeInterval(TimeInterval(i * 86400))
            daily.append(DailyWeather(date: date, tempMin: res.daily.temperature_2m_min[i], tempMax: res.daily.temperature_2m_max[i], condition: weatherCodeToCondition(res.daily.weather_code[i]), rainProbability: res.daily.precipitation_probability_max[i]))
        }
        
        return WeatherData(city: city, current: current, hourly: hourly, daily: daily)
    }
    
    private func weatherCodeToText(_ code: Int) -> String {
        switch code {
        case 0: return "Cielo Sereno"
        case 1, 2, 3: return "Parzialmente Nuvoloso"
        case 45, 48: return "Nebbia"
        case 51, 53, 55: return "Pioggerellina"
        case 61, 63, 65: return "Pioggia"
        case 71, 73, 75: return "Neve"
        case 95: return "Temporale"
        default: return "Variabile"
        }
    }
    
    private func weatherCodeToCondition(_ code: Int) -> String {
        switch code {
        case 0: return "sunny"
        case 1, 2, 3: return "cloudy"
        case 45, 48: return "fog"
        case 51, 53, 55, 61, 63, 65: return "rainy"
        case 71, 73, 75: return "snowy"
        case 95: return "thunder"
        default: return "sunny"
        }
    }
}

// MARK: - API Models
struct OpenMeteoResponse: Codable {
    let current: CurrentData
    let hourly: HourlyData
    let daily: DailyData
}

struct CurrentData: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let weather_code: Int
    let pressure_msl: Double
    let wind_speed_10m: Double
    let uv_index: Double
    let visibility: Double
}

struct HourlyData: Codable {
    let temperature_2m: [Double]
    let weather_code: [Int]
}

struct DailyData: Codable {
    let weather_code: [Int]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_probability_max: [Int]
}
