import Foundation

// WeatherAPI.comのレスポンス構造に合わせたモデル
struct WeatherApiResponse: Decodable {
    let location: Location
    let current: Current
}

struct Location: Decodable {
    let name: String
    let region: String
    let country: String
    let lat: Double
    let lon: Double
    let tz_id: String
    let localtime_epoch: Int
    let localtime: String
    
    // 地名を修正した新しいLocationを作成
    func withModifiedName(_ newName: String) -> Location {
        return Location(
            name: newName,
            region: self.region,
            country: self.country,
            lat: self.lat,
            lon: self.lon,
            tz_id: self.tz_id,
            localtime_epoch: self.localtime_epoch,
            localtime: self.localtime
        )
    }
}

struct Current: Decodable {
    let last_updated_epoch: Int
    let last_updated: String
    let temp_c: Double
    let temp_f: Double
    let is_day: Int
    let condition: Condition
    let wind_kph: Double
    let wind_degree: Int
    let wind_dir: String
    let pressure_mb: Double
    let precip_mm: Double
    let humidity: Int
    let cloud: Int
    let feelslike_c: Double
    let feelslike_f: Double
    let vis_km: Double
    let uv: Double
    let gust_kph: Double
}

struct Condition: Decodable {
    let text: String
    let icon: String
    let code: Int
}

enum WeatherError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case locationError
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURLです"
        case .invalidResponse: return "サーバーからの応答が無効です"
        case .invalidData: return "受信したデータが無効です"
        case .locationError: return "位置情報を取得できません"
        case .networkError: return "ネットワーク接続エラー"
        case .unknown: return "不明なエラーが発生しました"
        }
    }
}

// クジラAPIのレスポンスには、「データがない」場合にエラーオブジェクトが返される場合があります
struct KujiraError: Decodable {
    let error: String?
}

// 1日の天気予報
struct KujiraDayForecast: Decodable {
    let date: String
    let forecast: String
    let mintemp: String
    let maxtemp: String
    let poptimes: String
    let waves: String
    let winds: String
    let weathers: String?
}

// クジラWeb APIのレスポンス構造に合わせたモデル
struct KujiraWeatherResponse: Decodable {
    let mkdate: String
    let cities: [String: [KujiraDayForecast]]
    
    // カスタムデコーダー
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            return nil
        }
    }
    
    // 標準のイニシャライザ
    init(mkdate: String, cities: [String: [KujiraDayForecast]]) {
        self.mkdate = mkdate
        self.cities = cities
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // mkdateを取得
        if let mkdateKey = DynamicCodingKeys(stringValue: "mkdate"),
           let mkdate = try? container.decode(String.self, forKey: mkdateKey) {
            self.mkdate = mkdate
        } else {
            self.mkdate = ISO8601DateFormatter().string(from: Date())
        }
        
        // 都市データを動的に取得
        var cities = [String: [KujiraDayForecast]]()
        for key in container.allKeys {
            // mkdateキーはスキップ
            if key.stringValue == "mkdate" {
                continue
            }
            
            if let forecasts = try? container.decode([KujiraDayForecast].self, forKey: key) {
                cities[key.stringValue] = forecasts
            }
        }
        self.cities = cities
    }
    
    // データが取得できなかった場合に使用するダミーデータ
    static let dummy = KujiraWeatherResponse(
        mkdate: ISO8601DateFormatter().string(from: Date()),
        cities: [:]
    )
    
    // クジラAPI形式からWeatherApiResponseに変換するヘルパーメソッド
    func toWeatherApiResponse(for cityName: String) -> WeatherApiResponse {
        // 指定された都市の天気予報を取得
        guard let forecasts = cities[cityName], !forecasts.isEmpty else {
            // 都市が見つからない場合は東京の天気を使用するか、ダミーデータを返す
            if let tokyoForecasts = cities["東京"], !tokyoForecasts.isEmpty {
                return createWeatherResponse(cityName: "東京", forecast: tokyoForecasts[0])
            }
            
            // どの都市も見つからない場合は最初の都市を使用
            if let firstCity = cities.first {
                return createWeatherResponse(cityName: firstCity.key, forecast: firstCity.value[0])
            }
            
            // それもない場合はダミーデータ
            return createDummyWeatherResponse(cityName: cityName)
        }
        
        // 最初の日の予報を使用（今日の天気）
        return createWeatherResponse(cityName: cityName, forecast: forecasts[0])
    }
    
    // WeatherApiResponseを作成
    private func createWeatherResponse(cityName: String, forecast: KujiraDayForecast) -> WeatherApiResponse {
        // 気温の変換
        let tempC = Double(forecast.maxtemp) ?? 20.0
        
        // Locationオブジェクトの作成
        let locationObj = Location(
            name: cityName,
            region: "日本",
            country: "日本",
            lat: 35.6812, // デフォルト値（東京）
            lon: 139.7671, // デフォルト値（東京）
            tz_id: "Asia/Tokyo",
            localtime_epoch: Int(Date().timeIntervalSince1970),
            localtime: ISO8601DateFormatter().string(from: Date())
        )
        
        // 天気状態の変換
        let conditionText = forecast.forecast
        let conditionIcon = mapWeatherToIcon(conditionText)
        
        // Conditionオブジェクトの作成
        let condition = Condition(
            text: conditionText,
            icon: conditionIcon,
            code: mapWeatherToCode(conditionText)
        )
        
        // Currentオブジェクトの作成
        let current = Current(
            last_updated_epoch: Int(Date().timeIntervalSince1970),
            last_updated: ISO8601DateFormatter().string(from: Date()),
            temp_c: tempC,
            temp_f: celsiusToFahrenheit(tempC),
            is_day: isDay() ? 1 : 0,
            condition: condition,
            wind_kph: 0.0,
            wind_degree: 0,
            wind_dir: "N",
            pressure_mb: 1000.0,
            precip_mm: 0.0,
            humidity: 50,
            cloud: 0,
            feelslike_c: tempC,
            feelslike_f: celsiusToFahrenheit(tempC),
            vis_km: 10.0,
            uv: 0.0,
            gust_kph: 0.0
        )
        
        // WeatherApiResponseの作成
        return WeatherApiResponse(
            location: locationObj,
            current: current
        )
    }
    
    // ダミーデータを使用したレスポンスを作成
    private func createDummyWeatherResponse(cityName: String) -> WeatherApiResponse {
        // Locationオブジェクトの作成
        let locationObj = Location(
            name: cityName,
            region: "日本",
            country: "日本",
            lat: 35.6812, // 東京
            lon: 139.7671, // 東京
            tz_id: "Asia/Tokyo",
            localtime_epoch: Int(Date().timeIntervalSince1970),
            localtime: ISO8601DateFormatter().string(from: Date())
        )
        
        // Conditionオブジェクトの作成
        let condition = Condition(
            text: "晴れ",
            icon: "//cdn.weatherapi.com/weather/64x64/day/113.png",
            code: 1000
        )
        
        // Currentオブジェクトの作成
        let current = Current(
            last_updated_epoch: Int(Date().timeIntervalSince1970),
            last_updated: ISO8601DateFormatter().string(from: Date()),
            temp_c: 20.0,
            temp_f: 68.0,
            is_day: 1,
            condition: condition,
            wind_kph: 0.0,
            wind_degree: 0,
            wind_dir: "N",
            pressure_mb: 1000.0,
            precip_mm: 0.0,
            humidity: 50,
            cloud: 0,
            feelslike_c: 20.0,
            feelslike_f: 68.0,
            vis_km: 10.0,
            uv: 0.0,
            gust_kph: 0.0
        )
        
        return WeatherApiResponse(
            location: locationObj,
            current: current
        )
    }
    
    // 天気状態に基づいてアイコンURLを返す
    private func mapWeatherToIcon(_ weather: String) -> String {
        switch weather {
        case "晴", "晴れ", "快晴", "はれ":
            return "//cdn.weatherapi.com/weather/64x64/day/113.png"
        case "曇", "曇り", "くもり":
            return "//cdn.weatherapi.com/weather/64x64/day/119.png"
        case "雨", "小雨", "大雨", "あめ":
            return "//cdn.weatherapi.com/weather/64x64/day/308.png"
        case "雪", "大雪", "小雪", "ゆき":
            return "//cdn.weatherapi.com/weather/64x64/day/326.png"
        case "霧", "霞", "もや":
            return "//cdn.weatherapi.com/weather/64x64/day/248.png"
        case "雷", "雷雨", "かみなり":
            return "//cdn.weatherapi.com/weather/64x64/day/389.png"
        default:
            if weather.contains("晴") && weather.contains("曇") {
                return "//cdn.weatherapi.com/weather/64x64/day/116.png" // 晴れ時々曇り
            } else if weather.contains("晴") && weather.contains("雨") {
                return "//cdn.weatherapi.com/weather/64x64/day/176.png" // 晴れ時々雨
            } else if weather.contains("曇") && weather.contains("雨") {
                return "//cdn.weatherapi.com/weather/64x64/day/266.png" // 曇り時々雨
            } else {
                return "//cdn.weatherapi.com/weather/64x64/day/119.png" // デフォルト：曇り
            }
        }
    }
    
    // 天気状態に基づいてコードを返す
    private func mapWeatherToCode(_ weather: String) -> Int {
        switch weather {
        case "晴", "晴れ", "快晴", "はれ":
            return 1000 // 晴れ
        case "曇", "曇り", "くもり":
            return 1003 // 曇り
        case "雨", "小雨", "あめ":
            return 1063 // 雨
        case "大雨":
            return 1195 // 大雨
        case "雪", "ゆき":
            return 1066 // 雪
        case "大雪":
            return 1225 // 大雪
        case "霧", "霞", "もや":
            return 1030 // 霧
        case "雷", "雷雨", "かみなり":
            return 1087 // 雷
        default:
            if weather.contains("晴") && weather.contains("曇") {
                return 1003 // 晴れ時々曇り
            } else if weather.contains("晴") && weather.contains("雨") {
                return 1063 // 晴れ時々雨
            } else if weather.contains("曇") && weather.contains("雨") {
                return 1063 // 曇り時々雨
            } else {
                return 1003 // デフォルト：曇り
            }
        }
    }
    
    // 現在時刻が日中かどうかを判定
    private func isDay() -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        // 6時から18時を日中とする
        return hour >= 6 && hour < 18
    }
    
    // 摂氏を華氏に変換
    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9/5 + 32
    }
} 