# 「SimpleWeather」アプリ詳細設計書

## 1. アプリ概要

「SimpleWeather」は現在地および指定した場所の天気情報をシンプルに表示するiOSアプリです。ユーザーは現在地の天気を自動取得できるほか、地名や郵便番号を入力して任意の場所の天気情報を検索できます。検索履歴はCore Dataで保存され、アプリ再起動後も表示・再利用可能です。

## 2. 機能要件

### 主要機能
1. 現在地の天気・気温表示
2. 地名/郵便番号による天気検索
3. 検索履歴の保存・表示（Core Data使用）
4. アプリ再起動後も検索履歴を維持

### 技術要件
- 言語: Swift
- 開発環境: Xcode
- 対象OS: iOS 15.0以上
- 使用フレームワーク: SwiftUI, Core Data, CoreLocation
- 外部API: OpenWeatherMap API（無料プラン）

## 3. アーキテクチャ設計

MVVM（Model-View-ViewModel）パターンを採用します。

### コンポーネント構成
- **Models**: Core Dataモデル、API通信用モデル
- **Views**: SwiftUIビュー
- **ViewModels**: ビューとモデルの仲介役
- **Services**: API通信サービス、位置情報取得サービス

## 4. データモデル設計

### Core Dataモデル
```swift
// SearchHistory エンティティ
entity SearchHistory {
    // 主要属性
    uuid: UUID (primary key)
    searchTerm: String  // 検索した地名/郵便番号
    searchDate: Date    // 検索した日時
    
    // 検索結果の基本情報
    locationName: String
    temperature: Double
    weatherCondition: String
    weatherIcon: String
}
```

### APIレスポンスモデル
```swift
struct WeatherResponse: Decodable {
    let name: String
    let main: MainWeather
    let weather: [Weather]
    let sys: Sys
}

struct MainWeather: Decodable {
    let temp: Double
    let feels_like: Double
    let temp_min: Double
    let temp_max: Double
    let humidity: Int
}

struct Weather: Decodable {
    let id: Int
    let main: String
    let description: String
    let icon: String
}

struct Sys: Decodable {
    let country: String
}
```

## 5. 画面設計

### 画面構成
1. **メイン画面**: 現在地の天気表示エリア、検索ボックス、検索ボタン、検索履歴リスト
   - 上部: 現在地の天気表示
   - 中部: 検索ボックスと検索ボタン
   - 下部: 検索履歴リスト（スクロール可能）

### 主要画面のレイアウト
```
+---------------------------------+
|        SimpleWeather            |
+---------------------------------+
|                                 |
|   +-------------------------+   |
|   |    現在地の天気表示     |   |
|   |   東京  23°C  晴れ     |   |
|   |     (天気アイコン)      |   |
|   +-------------------------+   |
|                                 |
|   +-------------------------+   |
|   | 地名/郵便番号を入力     |   |
|   +-------------------------+   |
|   |       検索ボタン        |   |
|   +-------------------------+   |
|                                 |
|   検索履歴                      |
|   +-------------------------+   |
|   | 大阪 - 21°C 曇り        |   |
|   +-------------------------+   |
|   | 札幌 - 15°C 雨          |   |
|   +-------------------------+   |
|   |        ...              |   |
|   +-------------------------+   |
|                                 |
+---------------------------------+
```

## 6. コンポーネント詳細設計

### ViewModels

#### WeatherViewModel
```swift
class WeatherViewModel: ObservableObject {
    @Published var currentLocationWeather: WeatherResponse?
    @Published var searchedLocationWeather: WeatherResponse?
    @Published var searchHistory: [SearchHistory] = []
    @Published var searchTerm: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let weatherService: WeatherService
    private let locationService: LocationService
    private let dataController: DataController
    
    init(weatherService: WeatherService, locationService: LocationService, dataController: DataController) {
        self.weatherService = weatherService
        self.locationService = locationService
        self.dataController = dataController
        
        loadSearchHistory()
        getCurrentLocationWeather()
    }
    
    func getCurrentLocationWeather() { /* 実装 */ }
    func searchWeather(for location: String) { /* 実装 */ }
    func loadSearchHistory() { /* 実装 */ }
    func saveSearchToHistory(weather: WeatherResponse) { /* 実装 */ }
}
```

### Services

#### LocationService
```swift
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationError: Error?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() { /* 実装 */ }
    
    // CLLocationManagerDelegate メソッド
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { /* 実装 */ }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { /* 実装 */ }
}
```

#### WeatherService
```swift
class WeatherService {
    private let apiKey = "YOUR_OPENWEATHERMAP_API_KEY"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    
    func getWeather(latitude: Double, longitude: Double) async throws -> WeatherResponse { /* 実装 */ }
    func getWeather(for location: String) async throws -> WeatherResponse { /* 実装 */ }
}
```

#### DataController
```swift
class DataController: ObservableObject {
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "SimpleWeather")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
    
    func saveSearchHistory(searchTerm: String, weather: WeatherResponse) { /* 実装 */ }
    func fetchSearchHistory() -> [SearchHistory] { /* 実装 */ }
}
```

### Views

#### ContentView
```swift
struct ContentView: View {
    @StateObject var viewModel: WeatherViewModel
    
    var body: some View {
        VStack {
            CurrentWeatherView(weather: viewModel.currentLocationWeather)
            
            SearchBarView(
                searchTerm: $viewModel.searchTerm,
                onSearch: { viewModel.searchWeather(for: viewModel.searchTerm) }
            )
            
            if viewModel.searchedLocationWeather != nil {
                SearchedWeatherView(weather: viewModel.searchedLocationWeather)
            }
            
            SearchHistoryListView(
                history: viewModel.searchHistory,
                onItemSelected: { historyItem in
                    viewModel.searchTerm = historyItem.searchTerm
                    viewModel.searchWeather(for: historyItem.searchTerm)
                }
            )
        }
        .padding()
    }
}
```

## 7. API通信設計

### OpenWeatherMap API エンドポイント
- 現在の天気: `https://api.openweathermap.org/data/2.5/weather`

### APIリクエストパラメータ
- 座標による検索: `?lat={lat}&lon={lon}&appid={API key}&units=metric&lang=ja`
- 都市名による検索: `?q={city name}&appid={API key}&units=metric&lang=ja`
- 郵便番号による検索: `?zip={zip code},{country code}&appid={API key}&units=metric&lang=ja`

## 8. エラーハンドリング設計

```swift
enum WeatherError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidData
    case locationError
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .invalidData: return "Invalid data received"
        case .locationError: return "Unable to get location"
        case .networkError: return "Network connection error"
        case .unknown: return "An unknown error occurred"
        }
    }
}
```

## 9. セキュリティ対策

1. API キーの保護: Info.plist や設定ファイルではなく、環境変数やキーチェーンを利用
2. HTTPS通信の強制: App Transport Security 設定
3. 位置情報のプライバシー設定: 適切な説明文の提供

## 10. 開発工程

1. プロジェクト設定と基本UI構築: 2日
2. Core Dataモデル設計と実装: 1日
3. 位置情報取得機能の実装: 1日
4. API通信サービスの実装: 2日
5. 検索機能と履歴管理の実装: 2日
6. UIの完成と調整: 2日
7. テストとバグ修正: 3日

合計: 約2週間

## 11. 必要なパーミッション

- `NSLocationWhenInUseUsageDescription`: 位置情報取得のためのユーザー許可
- `NSAppTransportSecurity`: API通信のためのセキュリティ設定

## 12. 実装の注意点

1. API キーの取得と管理
2. エラー時のユーザーへのフィードバック
3. オフライン時の対応（保存データの表示）
4. Core Dataの適切な更新管理