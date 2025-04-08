//
//  ContentView.swift
//  SimpleWeather
//
//  Created by 濱田英樹 on 2025/04/08.
//

import SwiftUI
import CoreLocation
import CoreData

struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        ZStack(alignment: .top) {
            // メインコンテンツ
            ScrollView {
                VStack(spacing: 20) {
                    // アプリタイトル
                    Text("SimpleWeather")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // 天気表示：検索結果があればそれを表示、なければ現在地を表示
                    if let searchedWeather = viewModel.searchedLocationWeather {
                        // 検索結果の天気を表示
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("検索結果")
                                    .font(.headline)
                                
                                Spacer()
                                
                                // 現在地の天気に戻るボタン
                                Button(action: {
                                    viewModel.clearSearchResult()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location")
                                        Text("現在地の天気")
                                            .font(.subheadline)
                                    }
                                    .padding(6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                            
                            CurrentWeatherView(
                                weather: searchedWeather,
                                isLoading: false
                            )
                        }
                    } else {
                        // 現在地の天気を表示
                        CurrentWeatherView(
                            weather: viewModel.currentLocationWeather,
                            isLoading: viewModel.isLoading
                        )
                    }
                    
                    // 検索バー
                    SearchBarView(
                        searchTerm: $viewModel.searchTerm,
                        showingSearchHistory: $viewModel.showingSearchHistory,
                        searchHistory: viewModel.searchHistory,
                        onSearch: {
                            Task {
                                await viewModel.searchWeather(for: viewModel.searchTerm)
                            }
                            // 検索実行時に検索履歴を非表示に
                            viewModel.showingSearchHistory = false
                        },
                        onHistoryItemSelected: { history in
                            viewModel.historyItemSelected(history)
                        },
                        onSearchFieldTapped: {
                            viewModel.searchFieldTapped()
                        }
                    )
                    .padding(.horizontal)
                    
                    // エラーメッセージがあれば表示
                    if let errorMessage = viewModel.errorMessage {
                        ErrorMessageView(message: errorMessage)
                    }
                    
                    // 位置情報権限のステータス表示（デバッグ用）
                    #if DEBUG
                    VStack(alignment: .leading, spacing: 8) {
                        Text("位置情報の状態: \(locationStatusText(viewModel.locationAuthStatus))")
                            .font(.footnote)
                            .padding(.horizontal)
                            .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    #endif
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .edgesIgnoringSafeArea(.bottom)
            .onTapGesture {
                // 画面タップで検索履歴を閉じる
                viewModel.showingSearchHistory = false
            }
        }
    }
    
    private func locationStatusText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "未決定（許可を求めています）"
        case .restricted:
            return "制限あり"
        case .denied:
            return "拒否されました"
        case .authorizedAlways:
            return "常に許可"
        case .authorizedWhenInUse:
            return "使用中のみ許可"
        @unknown default:
            return "不明"
        }
    }
}

struct ErrorMessageView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .foregroundColor(.white)
            .padding()
            .background(Color.red.opacity(0.8))
            .cornerRadius(10)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, DataController.preview.container.viewContext)
    }
}
