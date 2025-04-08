# SimpleWeather

シンプルで使いやすい天気予報アプリ。現在地の天気を確認したり、世界中の地名で検索したりできます。

## アプリの概要

SimpleWeatherは、以下の機能を提供するiOSアプリです：

- 現在地の天気・気温表示
- 地名による天気検索
- 検索履歴の保存・表示
- 直感的でシンプルなUI

## システム要件

- iOS 15.0以上
- iPhone / iPad 対応

## 技術スタック

- **言語**: Swift
- **UI**: SwiftUI
- **アーキテクチャ**: MVVM (Model-View-ViewModel)
- **データ永続化**: Core Data
- **位置情報**: CoreLocation
- **API**: WeatherAPI.com

## プロジェクト構成

```
SimpleWeather/
├── SimpleWeatherApp.swift     # アプリエントリーポイント
├── ContentView.swift          # メイン画面
├── DataController.swift       # Core Data管理
├── Models/                    # データモデル
│   ├── WeatherModels.swift    # 天気データモデル
│   └── SearchHistory.swift    # 検索履歴モデル
├── Views/                     # UI層
│   ├── CurrentWeatherView.swift  # 天気表示ビュー
│   └── SearchBarView.swift    # 検索ビュー
├── ViewModels/                # ビジネスロジック
│   └── WeatherViewModel.swift # 天気VM
├── Services/                  # 外部サービス連携
│   ├── WeatherService.swift   # 天気API連携
│   └── LocationService.swift  # 位置情報取得
└── Assets.xcassets/           # 画像リソース
```

## 機能詳細

### 1. 現在地の天気表示

- CoreLocationを使用して現在地を取得
- 取得した座標をもとに天気情報を表示
- シミュレータでは東京の天気を表示

### 2. 地名検索

- 世界中の都市名で検索可能
- 日本語入力対応
- 検索結果の天気情報を表示

### 3. 検索履歴

- 検索した地名と天気情報をCore Dataに保存
- 最新3件の検索履歴を表示
- 履歴からワンタップで再検索可能

## アーキテクチャ

本アプリはMVVMアーキテクチャを採用しています：

- **Model**: Core Dataとデータモデル
- **View**: SwiftUIによるビュー
- **ViewModel**: ビューとモデルの橋渡し

## 開発環境のセットアップ

1. リポジトリをクローン
2. Xcodeでプロジェクトを開く
3. WeatherAPI.comでアカウントを作成し、APIキーを取得
4. `WeatherService.swift`内の`apiKey`変数にAPIキーを設定
5. ビルドして実行

## 使用方法

1. アプリを起動すると、現在地の天気が表示されます
2. 検索バーに地名を入力して検索ボタンをタップ
3. 検索結果の天気情報が表示されます
4. 「現在地の天気」ボタンをタップすると元の画面に戻ります
5. 時計アイコンをタップすると検索履歴が表示されます

