//
//  MPTappApp.swift
//  MPTapp
//
//  Created by Джаваншир Махмудов on 26.11.2025.
//

import SwiftUI

@main
struct MPTappApp: App {
    @StateObject private var contentService = ContentUpdateService.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    // Быстрая проверка обновлений при запуске
                    Task {
                        await contentService.checkAndUpdateIfNeeded()
                    }
                    // Запускаем автоматическую проверку каждые 5 минут
                    contentService.startAutoUpdate()
                }
        }
    }
}
