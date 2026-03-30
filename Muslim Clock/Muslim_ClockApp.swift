//
//  Muslim_ClockApp.swift
//  Muslim Clock
//
//  Created by Mohamed Kanoute on 27/03/2026.
//

import SwiftUI

@main
struct Muslim_ClockApp: App {
    
    init() {
            NotificationManager.shared.requestPermission()
        }
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
