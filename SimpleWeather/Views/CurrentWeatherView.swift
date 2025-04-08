import SwiftUI

struct CurrentWeatherView: View {
    let weather: WeatherApiResponse?
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                    .padding()
                Text("天気情報を取得中...")
            } else if let weather = weather {
                // 場所
                Text("\(weather.location.name), \(weather.location.country)")
                    .font(.title)
                    .fontWeight(.medium)
                
                // 天気アイコン
                if let iconUrl = URL(string: "https:\(weather.current.condition.icon)") {
                    AsyncImage(url: iconUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                    } placeholder: {
                        ProgressView()
                            .frame(width: 100, height: 100)
                    }
                }
                
                // 気温
                Text("\(Int(round(weather.current.temp_c)))°C")
                    .font(.system(size: 50, weight: .bold))
                
                // 天気状態
                Text(weather.current.condition.text)
                    .font(.title2)
                
                // 追加情報
                HStack(spacing: 20) {
                    WeatherDataItem(
                        title: "体感温度",
                        value: "\(Int(round(weather.current.feelslike_c)))°C",
                        icon: "thermometer"
                    )
                    
                    WeatherDataItem(
                        title: "湿度",
                        value: "\(weather.current.humidity)%",
                        icon: "drop.fill"
                    )
                }
            } else {
                Text("天気情報がありません")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct WeatherDataItem: View {
    var title: String
    var value: String
    var icon: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title)
                .padding(.bottom, 4)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CurrentWeatherView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // サンプルデータでのプレビュー
            CurrentWeatherView(
                weather: WeatherApiResponse(
                    location: Location(
                        name: "東京",
                        region: "東京都",
                        country: "日本",
                        lat: 35.69,
                        lon: 139.69,
                        tz_id: "Asia/Tokyo",
                        localtime_epoch: 1617161427,
                        localtime: "2021-03-31 13:30"
                    ),
                    current: Current(
                        last_updated_epoch: 1617161100,
                        last_updated: "2021-03-31 13:25",
                        temp_c: 23.5,
                        temp_f: 74.3,
                        is_day: 1,
                        condition: Condition(
                            text: "晴れ",
                            icon: "//cdn.weatherapi.com/weather/64x64/day/113.png",
                            code: 1000
                        ),
                        wind_kph: 14.4,
                        wind_degree: 180,
                        wind_dir: "S",
                        pressure_mb: 1012.0,
                        precip_mm: 0.0,
                        humidity: 65,
                        cloud: 0,
                        feelslike_c: 24.0,
                        feelslike_f: 75.2,
                        vis_km: 10.0,
                        uv: 6.0,
                        gust_kph: 16.2
                    )
                ),
                isLoading: false
            )
            .previewDisplayName("天気表示中")
            
            // 読み込み中
            CurrentWeatherView(
                weather: nil,
                isLoading: true
            )
            .previewDisplayName("読み込み中")
            
            // データなし
            CurrentWeatherView(
                weather: nil,
                isLoading: false
            )
            .previewDisplayName("データなし")
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
} 