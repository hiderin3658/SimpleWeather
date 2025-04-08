import Foundation
import CoreLocation

class WeatherService {
    // TODO: WeatherAPI.comのAPIキーに置き換えてください
    // 登録はこちら: https://www.weatherapi.com/signup.aspx
    private let apiKey = "32092023283e4d62b2660337250804"
    private let baseURL = "https://api.weatherapi.com/v1/current.json"
    
    // クジラWeb API用のURL
    private let kujiraBaseURL = "https://api.aoikujira.com/tenki/week.php"
    
    // API選択フラグ - 日本国内検索にはクジラAPIを使用
    private let useKujiraForJapan = true
    
    // 主要な日本の都市名を英語表記に変換するための辞書
    private let japaneseToEnglishCities: [String: String] = [
        "東京": "Tokyo",
        "横浜": "Yokohama",
        "大阪": "Osaka",
        "名古屋": "Nagoya",
        "札幌": "Sapporo",
        "福岡": "Fukuoka",
        "京都": "Kyoto",
        "神戸": "Kobe",
        "広島": "Hiroshima",
        "仙台": "Sendai",
        "千葉": "Chiba",
        "さいたま": "Saitama",
        "埼玉": "Saitama",
        "川崎": "Kawasaki",
        "北海道": "Hokkaido",
        "沖縄": "Okinawa",
        "那覇": "Naha",
        "新潟": "Niigata",
        "浜松": "Hamamatsu",
        "熊本": "Kumamoto",
        "静岡": "Shizuoka",
        "岡山": "Okayama",
        "鹿児島": "Kagoshima",
        "つくば": "Tsukuba",
        "金沢": "Kanazawa",
        "長崎": "Nagasaki",
        "宮崎": "Miyazaki",
        "松山": "Matsuyama",
        "京都市": "Kyoto",
        "大阪市": "Osaka",
        "東京都": "Tokyo",
        "京都府": "Kyoto",
        "大阪府": "Osaka",
//        "八尾市": "大阪",    // 八尾市は大阪として扱う <-- コメントアウト
        "大阪府八尾市": "大阪" // 八尾市は大阪として扱う
    ]
    
    // 特定の郵便番号から正確な地名へのマッピング
    private let postalCodeToLocation: [String: String] = [
        "6128483": "京都",    // 京都市伏見区横大路
        "1000001": "東京",    // 東京都千代田区
        "5300001": "大阪",    // 大阪市北区
        "2310023": "横浜"     // 横浜市中区
    ]
    
    // クジラAPIで使用できる都市ID一覧
    private let kujiraCityMap: [String: String] = [
        "札幌": "札幌",
        "仙台": "仙台",
        "東京": "東京",
        "新潟": "新潟",
        "金沢": "金沢",
        "名古屋": "名古屋",
        "大阪": "大阪",
        "広島": "広島",
        "高知": "高知",
        "福岡": "福岡",
        "鹿児島": "鹿児島",
        "那覇": "那覇",
        "横浜": "東京",  // 横浜は東京の天気を使用
        "大阪府": "大阪", // 大阪府は大阪の天気を使用
        "東京都": "東京"  // 東京都は東京の天気を使用
    ]
    
    func getWeather(latitude: Double, longitude: Double) async throws -> WeatherApiResponse {
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw WeatherError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "lang", value: "ja")
        ]
        
        guard let url = urlComponents.url else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(WeatherApiResponse.self, from: data)
        } catch {
            print("デコードエラー: \(error)")
            throw WeatherError.invalidData
        }
    }
    
    func getWeather(for location: String) async throws -> WeatherApiResponse {
        // 検索ロケーションが日本語や日本の地名かどうかを判定
        let isJapaneseSearch = isJapaneseLocation(location)
        
        // 日本語検索でクジラAPIを使用する設定の場合
        if useKujiraForJapan && isJapaneseSearch {
            // クジラAPI対応都市に変換
            let kujiraLocation = mapToKujiraCity(location)
            
            if !kujiraLocation.isEmpty {
                do {
                    print("🇯🇵 日本語地名を検出: クジラWeb APIを使用します（\(location) → \(kujiraLocation)）")
                    return try await getWeatherFromKujiraApi(for: kujiraLocation)
                } catch {
                    print("❌ クジラAPI検索エラー: \(error.localizedDescription)、WeatherAPI.comにフォールバックします")
                    // クジラAPIでエラーの場合、WeatherAPI.comにフォールバック
                    return try await getWeatherFromWeatherAPI(for: location)
                }
            }
        }
        
        return try await getWeatherFromWeatherAPI(for: location)
    }
    
    // クジラWeb APIを使用して天気を取得
    private func getWeatherFromKujiraApi(for location: String) async throws -> WeatherApiResponse {
        guard var urlComponents = URLComponents(string: kujiraBaseURL) else {
            throw WeatherError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "city", value: location),
            URLQueryItem(name: "fmt", value: "json")
        ]
        
        guard let url = urlComponents.url else {
            throw WeatherError.invalidURL
        }
        
        print("🔍 クジラAPI検索URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            
            // まずエラーのチェック（エラーレスポンスの場合がある）
            do {
                let errorResponse = try decoder.decode(KujiraError.self, from: data)
                if let errorMsg = errorResponse.error {
                    print("❌ クジラAPIエラー: \(errorMsg)")
                    throw WeatherError.invalidData
                }
            } catch {
                // エラーオブジェクトではない場合は続行
            }
            
            let kujiraResponse = try decoder.decode(KujiraWeatherResponse.self, from: data)
            
            // レスポンスが空の場合
            if kujiraResponse.cities.isEmpty {
                print("❌ クジラAPIからエラーまたは空のレスポンス")
                throw WeatherError.invalidData
            }
            
            print("✅ クジラAPI検索結果: \(location)の天気情報を取得しました")
            
            // クジラAPIのレスポンスをWeatherApiResponseに変換
            return kujiraResponse.toWeatherApiResponse(for: location)
        } catch {
            print("❌ クジラAPIデコードエラー: \(error)")
            throw WeatherError.invalidData
        }
    }
    
    // WeatherAPI.comを使用して天気を取得（既存のメソッドを分離）
    private func getWeatherFromWeatherAPI(for location: String) async throws -> WeatherApiResponse {
        // 郵便番号検索を無効化
        if isPostalCodeSearch(location) {
            print("📮 郵便番号での検索は無効です: \(location)")
            throw WeatherError.invalidData
        }
        
        // 郵便番号の場合はハイフンを削除し、日本の郵便番号であればJPプレフィックスを追加
        let cleanedLocation = cleanLocationString(location)
        
        guard var urlComponents = URLComponents(string: baseURL) else {
            throw WeatherError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: cleanedLocation),
            URLQueryItem(name: "lang", value: "ja")
        ]
        
        guard let url = urlComponents.url else {
            throw WeatherError.invalidURL
        }
        
        print("🔍 WeatherAPI検索URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }
        
        do {
            let decoder = JSONDecoder()
            var result = try decoder.decode(WeatherApiResponse.self, from: data)
            
            // "ベトナム"または"Vietnam"が含まれる日本語地名の場合、地名を修正
            if isJapaneseLocation(location) && (result.location.country == "ベトナム" || result.location.country == "Vietnam") {
                // 「八尾」が「八尾ノン」（ベトナム）として誤認識された場合の修正
                if location.contains("八尾") {
                    print("🔄 地名を修正: \(result.location.name), \(result.location.country) → 八尾市, 日本")
                    let correctedLocation = Location(
                        name: "八尾市",
                        region: "大阪府",
                        country: "日本",
                        lat: result.location.lat,
                        lon: result.location.lon,
                        tz_id: "Asia/Tokyo",
                        localtime_epoch: result.location.localtime_epoch,
                        localtime: result.location.localtime
                    )
                    
                    result = WeatherApiResponse(
                        location: correctedLocation,
                        current: result.current
                    )
                }
            }
            
            print("📍 取得した位置情報: \(result.location.name), \(result.location.region), \(result.location.country)")
            return result
        } catch {
            print("❌ WeatherAPIデコードエラー: \(error)")
            throw WeatherError.invalidData
        }
    }
    
    // 位置情報文字列を整形する（郵便番号のハイフン削除、日本語地名の英語変換など）
    private func cleanLocationString(_ location: String) -> String {
        // 郵便番号のパターンチェック
        if isPostalCodeSearch(location) {
            // ハイフンを削除
            let numericPostalCode = extractPostalCode(location)
            // 郵便番号から地名に変換
            if let japaneseName = postalCodeToLocation[numericPostalCode] { // japaneseName = "京都"
                print("📮 郵便番号を地名に変換: \(numericPostalCode) → \(japaneseName)")
                // さらに英語名に変換を試みる
                if let englishName = japaneseToEnglishCities[japaneseName] { // japaneseToEnglishCities["京都"] は "Kyoto"
                    print("📮 地名を英語に変換（郵便番号経由）: \(japaneseName) → \(englishName)")
                    return englishName // 英語名 "Kyoto" を返す
                } else {
                    // 英語名が見つからない場合は日本語名を返す（APIエラーの可能性あり）
                    print("⚠️ 英語名が見つからないため日本語地名を使用: \(japaneseName)")
                    return japaneseName // 日本語名 "京都" を返す
                }
            } else {
                // 辞書にない郵便番号の場合は、数字のみを返す
                print("📮 辞書にない郵便番号を使用: \(numericPostalCode)")
                return numericPostalCode
            }
        }
        
        // 日本語地名の場合、英語名に変換を試みる
        if let englishName = japaneseToEnglishCities[location] {
             print("🇯🇵 日本語地名を英語に変換: \(location) → \(englishName)")
            return englishName
        }
        
        // 上記以外はそのまま返す
         print("🗺️ 地名をそのまま使用: \(location)")
        return location
    }
    
    // 郵便番号検索かどうかを判定
    private func isPostalCodeSearch(_ search: String) -> Bool {
        // ハイフンありの場合 (例: 123-4567)
        let postalCodeWithHyphenPattern = "^\\d{3}-\\d{4}$"
        // ハイフンなしの場合 (例: 1234567)
        let postalCodePattern = "^\\d{7}$"
        
        let postalCodeWithHyphenPredicate = NSPredicate(format: "SELF MATCHES %@", postalCodeWithHyphenPattern)
        let postalCodePredicate = NSPredicate(format: "SELF MATCHES %@", postalCodePattern)
        
        return postalCodeWithHyphenPredicate.evaluate(with: search) || postalCodePredicate.evaluate(with: search)
    }
    
    // 郵便番号文字列からハイフンを除いた数字のみを抽出
    private func extractPostalCode(_ search: String) -> String {
        return search.replacingOccurrences(of: "-", with: "")
    }
    
    // 郵便番号から地名を取得
    private func getLocationNameForPostalCode(_ postalCode: String) -> String? {
        return postalCodeToLocation[postalCode]
    }
    
    // 検索文字列が日本語かどうかを判定
    private func isJapaneseLocation(_ location: String) -> Bool {
        // 日本語文字が含まれているか
        let japaneseRange = location.range(of: "\\p{Han}|\\p{Hiragana}|\\p{Katakana}", options: .regularExpression)
        
        // 郵便番号形式かどうか
        let isPostalCode = isPostalCodeSearch(location)
        
        // 日本の都市名辞書に含まれるか
        let isKnownJapaneseCity = japaneseToEnglishCities[location] != nil
        
        return japaneseRange != nil || isPostalCode || isKnownJapaneseCity
    }
    
    // 地名をクジラAPIで使用できる都市IDに変換
    private func mapToKujiraCity(_ location: String) -> String {
        // 郵便番号の場合、対応する都市に変換
        if isPostalCodeSearch(location) {
            let postalCode = extractPostalCode(location)
            if let city = postalCodeToLocation[postalCode], let kujiraCity = kujiraCityMap[city] {
                return kujiraCity
            }
        }
        
        // 直接クジラAPIの都市マップに含まれている場合はそのまま返す
        if let directCity = kujiraCityMap[location] {
            return directCity
        }
        
        // 日本語から英語に変換した地名があれば、それをクジラAPIの都市に変換
        if let englishCity = japaneseToEnglishCities[location], let kujiraCity = kujiraCityMap[englishCity] {
            return kujiraCity
        }
        
        // クジラAPI対応都市に含まれない場合は空文字を返す（WeatherAPI.comにフォールバック）
        return ""
    }
} 