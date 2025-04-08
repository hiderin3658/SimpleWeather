import Foundation
import CoreData

// 検索履歴の機能を拡張するための拡張
extension SearchHistory {
    // 指定された検索条件で検索履歴を作成する
    static func createSearchHistory(
        searchTerm: String,
        locationName: String,
        temperature: Double,
        weatherCondition: String,
        weatherIcon: String,
        in context: NSManagedObjectContext
    ) -> SearchHistory {
        let history = SearchHistory(context: context)
        history.id = UUID()
        history.searchTerm = searchTerm
        history.searchDate = Date()
        history.locationName = locationName
        history.temperature = temperature
        history.weatherCondition = weatherCondition
        history.weatherIcon = weatherIcon
        
        // コンテキストを保存
        do {
            try context.save()
        } catch {
            print("検索履歴の保存に失敗しました: \(error)")
        }
        
        return history
    }
    
    // 最新の検索履歴を取得する（最大件数指定可能）
    static func fetchLatestHistory(limit: Int = 5, in context: NSManagedObjectContext) -> [SearchHistory] {
        let request: NSFetchRequest<SearchHistory> = SearchHistory.fetchRequest()
        
        // 検索日時の降順で並べ替え（最新順）
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SearchHistory.searchDate, ascending: false)]
        
        // 取得件数を制限
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("検索履歴の取得に失敗しました: \(error)")
            return []
        }
    }
    
    // 重複する検索履歴を削除する
    static func removeDuplicateHistory(for searchTerm: String, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<SearchHistory> = SearchHistory.fetchRequest()
        
        // 指定した検索条件に一致する履歴を検索
        request.predicate = NSPredicate(format: "searchTerm == %@", searchTerm)
        
        do {
            let existingHistories = try context.fetch(request)
            
            // 見つかった履歴を削除
            for history in existingHistories {
                context.delete(history)
            }
            
            try context.save()
        } catch {
            print("重複する検索履歴の削除に失敗しました: \(error)")
        }
    }
    
    // 古い履歴を削除して最大件数を維持する
    static func maintainHistoryLimit(limit: Int = 10, in context: NSManagedObjectContext) {
        let request: NSFetchRequest<SearchHistory> = SearchHistory.fetchRequest()
        
        // 検索日時の降順で並べ替え（最新順）
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SearchHistory.searchDate, ascending: false)]
        
        do {
            let allHistories = try context.fetch(request)
            
            // 制限を超える古い履歴を削除
            if allHistories.count > limit {
                for i in limit..<allHistories.count {
                    context.delete(allHistories[i])
                }
                
                try context.save()
            }
        } catch {
            print("検索履歴の制限維持に失敗しました: \(error)")
        }
    }
} 