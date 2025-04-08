import SwiftUI
import UIKit

struct SearchBarView: View {
    @Binding var searchTerm: String
    @Binding var showingSearchHistory: Bool
    var searchHistory: [SearchHistory]
    var onSearch: () -> Void
    var onHistoryItemSelected: (SearchHistory) -> Void
    var onSearchFieldTapped: () -> Void
    
    var body: some View {
        ZStack(alignment: .top) {
            // メインのVStackコンテンツ
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("地名を入力", text: $searchTerm)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    
                    // 検索履歴表示ボタン
                    Button(action: {
                        // キーボードを閉じる
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        // 少し遅延させて検索履歴を表示（キーボードが完全に閉じた後）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onSearchFieldTapped()
                        }
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 5)
                    
                    if !searchTerm.isEmpty {
                        Button(action: {
                            searchTerm = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Button(action: onSearch) {
                    Text("検索")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(searchTerm.isEmpty)
                .opacity(searchTerm.isEmpty ? 0.6 : 1.0)
            }
            .padding()
            
            // 検索履歴をオーバーレイとして表示
            if showingSearchHistory && !searchHistory.isEmpty {
                VStack {
                    // 検索履歴の表示位置を調整
                    Spacer().frame(height: -20)
                    
                    SearchHistoryView(
                        searchHistory: searchHistory,
                        onHistoryItemSelected: onHistoryItemSelected
                    )
                    .padding(.horizontal)
                }
                .zIndex(1) // 重なりの優先順位を設定
            }
        }
    }
}

struct SearchHistoryView: View {
    let searchHistory: [SearchHistory]
    let onHistoryItemSelected: (SearchHistory) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("最近の検索")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.top, 5)
            
            ForEach(searchHistory) { history in
                SearchHistoryItemView(history: history)
                    .onTapGesture {
                        onHistoryItemSelected(history)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
        .padding(.bottom, 5)
        .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
}

struct SearchHistoryItemView: View {
    let history: SearchHistory
    
    var body: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.gray)
                .frame(width: 25)
            
            VStack(alignment: .leading) {
                if let searchTerm = history.searchTerm {
                    Text(searchTerm)
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                if let locationName = history.locationName {
                    Text(locationName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // temperatureは非Optionalなので直接使用
            Text(String(format: "%.1f°C", history.temperature))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            // 天気アイコン（オプション）
            if let icon = history.weatherIcon, !icon.isEmpty {
                AsyncImage(url: URL(string: "https:\(icon)")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                } placeholder: {
                    Image(systemName: "cloud")
                        .frame(width: 30, height: 30)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal, 5)
    }
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        // サンプルデータを作成
        let previewContext = DataController.preview.container.viewContext
        let sampleHistory = SearchHistory.fetchLatestHistory(in: previewContext)
        
        return SearchBarView(
            searchTerm: .constant("東京"),
            showingSearchHistory: .constant(true),
            searchHistory: sampleHistory,
            onSearch: {},
            onHistoryItemSelected: { _ in },
            onSearchFieldTapped: {}
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
