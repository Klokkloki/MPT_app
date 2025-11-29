import Foundation
import SwiftUI

// MARK: - Content Update Service
/// Сервис для обновления контента (рекламы, новостей) с сервера

class ContentUpdateService: ObservableObject {
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
        
        do {
            // Проверяем, нужно ли обновлять (если последнее обновление было менее часа назад)
            if !force, let lastUpdate = lastUpdateTime,
               Date().timeIntervalSince(lastUpdate) < 3600 { // 1 час
                isLoading = false
                return
            }
            
            // Загружаем рекламу
            if let ads = try? await fetchAdvertisements() {
                advertisements = ads
                saveAdvertisements(ads)
            }
            
            // Загружаем новости
            if let news = try? await fetchNews() {
                newsItems = news
                saveNews(news)
            }
            
            // Получаем и сохраняем версию контента
            if let versionResponse = try? await fetchContentVersion() {
                storage.set(versionResponse.version, forKey: "content_version")
                storage.set(versionResponse.timestamp, forKey: "content_timestamp")
            }
            
            lastUpdateTime = Date()
            storage.set(Date(), forKey: updateTimeKey)
            
        } catch {
            print("Ошибка обновления контента: \(error)")
            // При ошибке используем кеш
            loadCachedContent()
        }
        
        isLoading = false
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
    
    /// Проверить версию контента на сервере
    func checkForUpdates() async -> Bool {
        do {
            let baseURL = await NetworkService.shared.baseURL
            let url = URL(string: "\(baseURL)/api/content/version")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode([String: String].self, from: data)
            
            let serverVersion = response["version"] ?? "1"
            let localVersion = storage.string(forKey: "content_version") ?? "0"
            
            return serverVersion != localVersion
        } catch {
            print("Ошибка проверки обновлений: \(error)")
            return false
        }
    }
    
    private func fetchContentVersion() async throws -> ContentVersion {
        let baseURL = await NetworkService.shared.baseURL
        let url = URL(string: "\(baseURL)/api/content/version")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ContentVersion.self, from: data)
    }
    
    private struct ContentVersion: Codable {
        let version: String
        let timestamp: String?
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
