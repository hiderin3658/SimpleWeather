//
//  SimpleWeatherApp.swift
//  SimpleWeather
//
//  Created by 濱田英樹 on 2025/04/08.
//

import SwiftUI

@main
struct SimpleWeatherApp: App {
    // Core Dataコントローラを初期化
    let dataController = DataController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // ContentViewにCore Dataコンテキストを提供
                .environment(\.managedObjectContext, dataController.container.viewContext)
        }
    }
}
