import Foundation
import SwiftUI

// MARK: - Content Update Service
/// Сервис для обновления контента (рекламы, новостей) с сервера

@MainActor
final class ContentUpdateService: ObservableObject {
    static let shared = ContentUpdateService()
    
    @Published var advertisements: [Advertisement] = []
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    private let networkService = NetworkService.shared
    private let storage = UserDefaults.standard
    
    // Ключи для кеширования
    private let adsKey = "cached_advertisements"
    private let newsKey = "cached_news_items"
    private let updateTimeKey = "last_content_update"
    private var updateTimer: Timer?
    private var pendingServerVersion: String?
    
    private init() {
        loadCachedContent()
    }
    
    // MARK: - Public Methods
    
    /// Загрузить контент с сервера (или использовать кеш)
    func updateContent() {
        Task {
            await fetchContentFromServer()
        }
    }
    
    /// Принудительно обновить с сервера
    func forceUpdate() {
        Task {
            await fetchContentFromServer(force: true)
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func fetchContentFromServer(force: Bool = false) async {
        isLoading = true
        
        let needsUpdate = force ? true : await checkForUpdates()
        
        guard needsUpdate else {
            isLoading = false
            return
        }
        
        do {
            let ads = try await fetchAdvertisements()
            advertisements = ads
            saveAdvertisements(ads)
            
            let news = try await fetchNews()
            newsItems = news
            saveNews(news)
            
            let version: String
            if let pending = pendingServerVersion {
                version = pending
                pendingServerVersion = nil
            } else {
                version = try await fetchContentVersion()
            }
            storage.set(version, forKey: "content_version")
            
            lastUpdateTime = Date()
            storage.set(lastUpdateTime, forKey: updateTimeKey)
            
        } catch {
            print("Ошибка обновления контента: \(error)")
            loadCachedContent()
        }
        
        isLoading = false
    }
    
    /// Быстрая проверка версии (без загрузки всего контента)
    @MainActor
    private func fetchContentVersion() async throws -> String {
        let baseURL = await NetworkService.shared.baseURL
        let url = URL(string: "\(baseURL)/api/content/version")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: String].self, from: data)
        return response["version"] ?? "1.0"
    }
    
    // MARK: - API Calls
    
    private func fetchAdvertisements() async throws -> [Advertisement] {
        let baseURL = await NetworkService.shared.baseURL
        let url = URL(string: "\(baseURL)/api/content/advertisements")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: [AdvertisementAPI]].self, from: data)
        
        return response["advertisements"]?.map { apiAd in
            Advertisement(
                id: UUID(uuidString: apiAd.id) ?? UUID(),
                title: apiAd.title,
                description: apiAd.description,
                imageName: apiAd.imageName,
                url: apiAd.url,
                category: AdCategory(rawValue: apiAd.category) ?? .course
            )
        } ?? []
    }
    
    private func fetchNews() async throws -> [NewsItem] {
        let baseURL = await NetworkService.shared.baseURL
        let url = URL(string: "\(baseURL)/api/content/news")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode([String: [NewsItemAPI]].self, from: data)
        
        return response["news"]?.map { apiNews in
            NewsItem(
                id: UUID(uuidString: apiNews.id) ?? UUID(),
                imageName: apiNews.imageName,
                title: apiNews.title,
                description: apiNews.description
            )
        } ?? []
    }
    
    // MARK: - API Models
    
    private struct AdvertisementAPI: Codable {
        let id: String
        let title: String
        let description: String
        let imageName: String?
        let url: String?
        let category: String
    }
    
    private struct NewsItemAPI: Codable {
        let id: String
        let imageName: String
        let title: String?
        let description: String?
    }
    
    /// Проверить версию контента на сервере (быстрая проверка)
    func checkForUpdates() async -> Bool {
        do {
            let baseURL = await NetworkService.shared.baseURL
            let url = URL(string: "\(baseURL)/api/content/version")!
            
            // Быстрый запрос с таймаутом 3 секунды
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.0
            request.cachePolicy = .reloadIgnoringLocalCacheData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode([String: String].self, from: data)
            
            let serverVersion = response["version"] ?? "1.0"
            let localVersion = storage.string(forKey: "content_version") ?? "0"
            
            let hasUpdate = serverVersion != localVersion
            if hasUpdate {
                pendingServerVersion = serverVersion
            }
            return hasUpdate
        } catch {
            print("Ошибка проверки обновлений: \(error)")
            return false
        }
    }
    
    /// Автоматическая проверка обновлений (вызывается периодически)
    func startAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(timeInterval: 300, target: self, selector: #selector(handleUpdateTimer), userInfo: nil, repeats: true)
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        Task {
            await checkAndUpdateIfNeeded()
        }
    }
    
    /// Остановка таймера (если понадобится)
    func stopAutoUpdate() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @objc private func handleUpdateTimer() {
        Task {
            await checkAndUpdateIfNeeded()
        }
    }
    
    /// Проверить и обновить если нужно
    func checkAndUpdateIfNeeded() async {
        let needsUpdate = await checkForUpdates()
        if needsUpdate {
            await fetchContentFromServer(force: false)
        }
    }
    
    // MARK: - Local Storage
    
    private func loadCachedContent() {
        // Загружаем рекламу из кеша
        if let data = storage.data(forKey: adsKey),
           let ads = try? JSONDecoder().decode([Advertisement].self, from: data) {
            advertisements = ads
        } else {
            // Фолбэк на дефолтные значения
            advertisements = []
        }
        
        // Загружаем новости из кеша
        if let data = storage.data(forKey: newsKey),
           let news = try? JSONDecoder().decode([NewsItem].self, from: data) {
            newsItems = news
        } else {
            newsItems = [
                NewsItem(imageName: "00.10.2024", title: "Экскурсия", description: "Студенты МПТ на экскурсии"),
                NewsItem(imageName: "head", title: "Новости колледжа", description: "Следите за событиями"),
                NewsItem(imageName: "prevyu-studenty-mpt-na-obshherossijskom-turnire-po-robototehnike-24-26.09.2025", title: "Робототехника", description: "Студенты МПТ на всероссийском турнире")
            ]
        }
        
        // Загружаем время последнего обновления
        if let date = storage.object(forKey: updateTimeKey) as? Date {
            lastUpdateTime = date
        }
    }
    
    private func saveAdvertisements(_ ads: [Advertisement]) {
        if let data = try? JSONEncoder().encode(ads) {
            storage.set(data, forKey: adsKey)
        }
    }
    
    private func saveNews(_ news: [NewsItem]) {
        if let data = try? JSONEncoder().encode(news) {
            storage.set(data, forKey: newsKey)
        }
    }
}

