//
//  SimpleWeatherApp.swift
//  SimpleWeather
//
//  Created by 濱田英樹 on 2025/04/08.
//

import SwiftUI

@main
struct SimpleWeatherApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
