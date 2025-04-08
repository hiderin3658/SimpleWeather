import CoreData
import Foundation

class DataController: ObservableObject {
    // 共有インスタンス
    static let shared = DataController()
    
    // Core Dataのコンテナ
    let container: NSPersistentContainer
    
    // プレビュー用のテストデータ（SwiftUIプレビュー用）
    static var preview: DataController = {
        let controller = DataController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // サンプルデータを作成
        for i in 0..<5 {
            let history = SearchHistory(context: viewContext)
            history.id = UUID()
            history.searchTerm = "サンプル検索\(i+1)"
            history.searchDate = Date().addingTimeInterval(-Double(i) * 3600) // 1時間ずつ過去
            history.locationName = "サンプル都市\(i+1)"
            history.temperature = Double(20 + i)
            history.weatherCondition = "晴れ"
            history.weatherIcon = "01d"
        }
        
        try? viewContext.save()
        return controller
    }()
    
    // 初期化
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SimpleWeather")
        
        // メモリ内ストレージ（テスト用）の設定
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // 永続ストアの読み込み
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data読み込みエラー: \(error.localizedDescription)")
            }
        }
        
        // 親コンテキストからの変更を自動的にマージする設定
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // 検索履歴の保存
    func saveSearchHistory(searchTerm: String, weather: WeatherApiResponse) {
        let context = container.viewContext
        
        // 重複する検索を削除
        SearchHistory.removeDuplicateHistory(for: searchTerm, in: context)
        
        // 新しい検索履歴を作成
        _ = SearchHistory.createSearchHistory(
            searchTerm: searchTerm,
            locationName: weather.location.name,
            temperature: weather.current.temp_c,
            weatherCondition: weather.current.condition.text,
            weatherIcon: weather.current.condition.icon,
            in: context
        )
        
        // 履歴が多すぎないように制限を維持
        SearchHistory.maintainHistoryLimit(limit: 10, in: context)
    }
    
    // 最新の検索履歴を取得
    func fetchLatestHistory(limit: Int = 3) -> [SearchHistory] {
        return SearchHistory.fetchLatestHistory(limit: limit, in: container.viewContext)
    }
} 