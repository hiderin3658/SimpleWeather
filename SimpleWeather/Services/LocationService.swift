import Foundation
import CoreLocation

class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var locationError: Error?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // シミュレータ用の固定位置情報
    #if targetEnvironment(simulator)
    private let useFixedLocation = true
    // 東京の位置情報を使用
    private let fixedLocation = CLLocation(
        latitude: 35.6812, // 東京の緯度
        longitude: 139.7671 // 東京の経度
    )
    #else
    private let useFixedLocation = false
    #endif
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = locationManager.authorizationStatus
        
        #if targetEnvironment(simulator)
        // シミュレータでは位置情報設定を無視して、強制的に東京の位置情報を設定
        if useFixedLocation {
            // すぐに東京の位置情報を設定
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.location = self.fixedLocation
                print("📍 シミュレータ用固定位置を設定: 東京 (35.6812, 139.7671)")
            }
            // Xcodeのシミュレータの位置情報設定を上書きするためのトリック
            locationManager.stopUpdatingLocation()
        }
        #endif
    }
    
    func requestLocation() {
        #if targetEnvironment(simulator)
        if useFixedLocation {
            // シミュレータの場合は常に東京の位置情報を返す
            self.location = fixedLocation
            print("📍 requestLocation: 東京の固定位置情報を返します")
            return
        }
        #endif
        
        checkPermissionAndRequestLocation()
    }
    
    // シミュレータで位置を変更するための関数（デバッグ用）
    func setDebugLocation(latitude: Double, longitude: Double) {
        let newLocation = CLLocation(latitude: latitude, longitude: longitude)
        self.location = newLocation
        print("📍 デバッグ位置を設定: (\(latitude), \(longitude))")
    }
    
    private func checkPermissionAndRequestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            self.locationError = NSError(
                domain: kCLErrorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "位置情報へのアクセスが許可されていません。設定アプリから位置情報サービスを有効にしてください。"]
            )
            
            #if targetEnvironment(simulator)
            if useFixedLocation {
                // 権限がなくても固定位置を返す
                self.location = fixedLocation
            }
            #endif
        case .authorizedAlways, .authorizedWhenInUse:
            #if targetEnvironment(simulator)
            if useFixedLocation {
                // シミュレータでは位置情報を許可されても東京の位置を使用
                self.location = fixedLocation
            } else {
                locationManager.requestLocation()
            }
            #else
            locationManager.requestLocation()
            #endif
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        #if targetEnvironment(simulator)
        if useFixedLocation {
            // シミュレータでは位置情報アップデートを無視して東京の位置を使用
            self.location = fixedLocation
            print("📍 位置情報更新を無視: 東京の固定位置情報を使用")
            return
        }
        #endif
        
        if let location = locations.first {
            self.location = location
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // GPS信号が弱い場合などのエラー処理
        self.locationError = error
        
        // デバッグ情報を出力
        print("位置情報取得エラー: \(error.localizedDescription)")
        if let clError = error as? CLError {
            print("CLエラーコード: \(clError.code.rawValue)")
        }
        
        // シミュレータの場合はエラー後に固定位置を設定
        #if targetEnvironment(simulator)
        if useFixedLocation {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.location = self.fixedLocation
                print("📍 位置情報エラー後、シミュレータ用固定位置を設定: 東京")
            }
        }
        #endif
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            #if targetEnvironment(simulator)
            if useFixedLocation {
                self.location = fixedLocation
                print("📍 権限変更後、固定位置を設定: 東京")
            } else {
                locationManager.requestLocation()
            }
            #else
            locationManager.requestLocation()
            #endif
        case .denied, .restricted:
            self.locationError = NSError(
                domain: kCLErrorDomain,
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "位置情報へのアクセスが許可されていません。設定アプリから位置情報サービスを有効にしてください。"]
            )
            
            // シミュレータでは許可がなくても固定位置を使用
            #if targetEnvironment(simulator)
            if useFixedLocation {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.location = self.fixedLocation
                    print("📍 権限拒否後、シミュレータ用固定位置を設定: 東京")
                }
            }
            #endif
        case .notDetermined:
            // 許可待ち
            break
        @unknown default:
            break
        }
    }
} 