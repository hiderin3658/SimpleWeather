import Foundation
import CoreLocation
import SwiftUI
import Combine
import CoreData

class WeatherViewModel: ObservableObject {
    @Published var currentLocationWeather: WeatherApiResponse?
    @Published var searchedLocationWeather: WeatherApiResponse?
    @Published var searchTerm: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var locationAuthStatus: CLAuthorizationStatus = .notDetermined
    @Published var searchHistory: [SearchHistory] = []
    @Published var showingSearchHistory: Bool = false
    
    private let weatherService: WeatherService
    private let locationService: LocationService
    private let dataController: DataController
    private var cancellables = Set<AnyCancellable>()
    
    init(weatherService: WeatherService = WeatherService(), 
         locationService: LocationService = LocationService(),
         dataController: DataController = DataController.shared) {
        self.weatherService = weatherService
        self.locationService = locationService
        self.dataController = dataController
        
        // 検索履歴をロード
        loadSearchHistory()
        
        // 位置情報の更新を監視
        locationService.$location
            .sink { [weak self] location in
                guard let self = self, let location = location else { return }
                
                // デバッグログを追加
                print("📍 位置情報を受信: lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")
                
                Task {
                    await self.fetchWeatherForCurrentLocation(location: location)
                }
            }
            .store(in: &cancellables)
        
        locationService.$locationError
            .sink { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    if let clError = error as? CLError {
                        switch clError.code {
                        case .denied:
                            self.errorMessage = "位置情報へのアクセスが拒否されました。設定アプリから許可してください。"
                        case .locationUnknown:
                            self.errorMessage = "位置情報を取得できませんでした。ネットワーク接続や位置情報サービスを確認してください。"
                        default:
                            self.errorMessage = "位置情報エラー: \(error.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    self.errorMessage = nil
                }
            }
            .store(in: &cancellables)
        
        locationService.$authorizationStatus
            .sink { [weak self] status in
                self?.locationAuthStatus = status
                
                switch status {
                case .denied, .restricted:
                    self?.errorMessage = "位置情報へのアクセスが許可されていません。設定アプリから位置情報サービスを有効にしてください。"
                    
                    #if targetEnvironment(simulator)
                    // シミュレータでは権限がなくても東京の天気を表示
                    self?.setCustomLocation(latitude: 35.6812, longitude: 139.7671)
                    #endif
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // 初期化時に位置情報をリクエスト
        locationService.requestLocation()
        
        // シミュレータの場合、すぐに東京の位置情報で天気を取得
        #if targetEnvironment(simulator)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setCustomLocation(latitude: 35.6812, longitude: 139.7671)
        }
        #endif
    }
    
    // 検索履歴をロードする
    func loadSearchHistory() {
        self.searchHistory = dataController.fetchLatestHistory()
    }
    
    // 検索入力フィールドをタップしたときの処理
    func searchFieldTapped() {
        // 最新の3件の検索履歴を取得して表示
        self.searchHistory = dataController.fetchLatestHistory(limit: 3)
        // 検索履歴を表示
        showingSearchHistory = true
    }
    
    // 検索履歴アイテムをタップしたときの処理
    func historyItemSelected(_ history: SearchHistory) {
        guard let searchTerm = history.searchTerm else { return }
        
        // 検索テキストを更新
        self.searchTerm = searchTerm
        
        // 検索を実行
        Task {
            await searchWeather(for: searchTerm)
        }
        
        // 検索履歴の表示を閉じる
        showingSearchHistory = false
    }
    
    // 手動で位置情報を設定（シミュレータ用）
    func setCustomLocation(latitude: Double, longitude: Double) {
        locationService.setDebugLocation(latitude: latitude, longitude: longitude)
    }
    
    @MainActor
    func fetchWeatherForCurrentLocation(location: CLLocation) async {
        do {
            isLoading = true
            errorMessage = nil
            
            let weather = try await weatherService.getWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            currentLocationWeather = weather
            isLoading = false
        } catch {
            isLoading = false
            handleWeatherError(error)
        }
    }
    
    @MainActor
    func searchWeather(for location: String) async {
        guard !location.isEmpty else { return }
        
        do {
            isLoading = true
            errorMessage = nil
            
            // 検索前にロケーション名をログに出力
            print("🔍 検索キーワード: \(location)")
            
            let weather = try await weatherService.getWeather(for: location)
            
            // 検索結果の詳細をログに出力
            print("✅ 検索結果: \(weather.location.name), \(weather.location.region), \(weather.location.country)")
            
            // 検索結果を反映
            searchedLocationWeather = weather
            
            // 検索履歴に保存
            dataController.saveSearchHistory(searchTerm: location, weather: weather)
            
            // 検索履歴を更新
            loadSearchHistory()
            
            isLoading = false
        } catch {
            isLoading = false
            handleWeatherError(error)
            print("❌ 検索エラー: \(error.localizedDescription)")
        }
    }
    
    private func handleWeatherError(_ error: Error) {
        if let weatherError = error as? WeatherError {
            switch weatherError {
            case .invalidURL:
                errorMessage = "無効なURLです。"
            case .invalidResponse:
                errorMessage = "サーバーからの応答が無効です。ネットワーク接続を確認してください。"
            case .invalidData:
                errorMessage = "無効なデータを受信しました。"
            case .locationError:
                errorMessage = "位置情報を取得できませんでした。"
            case .networkError:
                errorMessage = "ネットワーク接続エラーが発生しました。インターネット接続を確認してください。"
            case .unknown:
                errorMessage = "不明なエラーが発生しました。"
            }
        } else {
            errorMessage = "エラー: \(error.localizedDescription)"
        }
        
        // APIキーが無効または未設定の場合の特別処理
        if error.localizedDescription.contains("Invalid API key") || 
           error.localizedDescription.contains("Authentication failed") {
            errorMessage = "APIキーが無効または未設定です。WeatherService.swiftファイルでAPIキーを設定してください。"
        }
    }
    
    // 検索結果をクリアして現在地の天気表示に戻る
    func clearSearchResult() {
        searchedLocationWeather = nil
        searchTerm = ""
    }
} 