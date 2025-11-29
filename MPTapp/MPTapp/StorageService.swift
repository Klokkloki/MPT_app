import Foundation

/// Сервис для локального хранения данных (UserDefaults)
class StorageService {
    static let shared = StorageService()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    
    private enum Keys {
        static let homeworks = "saved_homeworks"
        static let cachedWeekInfo = "cached_week_info"
        static let cachedSpecialties = "cached_specialties"
        static let cachedGroups = "cached_groups_" // + specialtyId
        static let cachedSchedule = "cached_schedule_" // + groupId
        static let cachedReplacements = "cached_replacements_" // + groupId
        static let lastUpdateTime = "last_update_time_"
    }
    
    private init() {}
    
    // MARK: - Homeworks (ДЗ)
    
    func saveHomeworks(_ homeworks: [UUID: Homework]) {
        // Конвертируем [UUID: Homework] в [String: Homework] для кодирования
        var dict: [String: Homework] = [:]
        for (key, value) in homeworks {
            dict[key.uuidString] = value
        }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(dict) {
            defaults.set(encoded, forKey: Keys.homeworks)
        }
    }
    
    func loadHomeworks() -> [UUID: Homework] {
        guard let data = defaults.data(forKey: Keys.homeworks),
              let decoded = try? JSONDecoder().decode([String: Homework].self, from: data) else {
            return [:]
        }
        // Конвертируем String keys в UUID
        var result: [UUID: Homework] = [:]
        for (key, value) in decoded {
            if let uuid = UUID(uuidString: key) {
                result[uuid] = value
            }
        }
        return result
    }
    
    // MARK: - Week Info
    
    func saveWeekInfo(_ weekInfo: WeekInfo) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(weekInfo) {
            defaults.set(encoded, forKey: Keys.cachedWeekInfo)
            defaults.set(Date(), forKey: Keys.lastUpdateTime + "week_info")
        }
    }
    
    func loadWeekInfo() -> WeekInfo? {
        guard let data = defaults.data(forKey: Keys.cachedWeekInfo),
              let weekInfo = try? JSONDecoder().decode(WeekInfo.self, from: data) else {
            return nil
        }
        return weekInfo
    }
    
    // MARK: - Specialties
    
    func saveSpecialties(_ specialties: [Specialty]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(specialties) {
            defaults.set(encoded, forKey: Keys.cachedSpecialties)
            defaults.set(Date(), forKey: Keys.lastUpdateTime + "specialties")
        }
    }
    
    func loadSpecialties() -> [Specialty]? {
        guard let data = defaults.data(forKey: Keys.cachedSpecialties),
              let specialties = try? JSONDecoder().decode([Specialty].self, from: data) else {
            return nil
        }
        return specialties
    }
    
    // MARK: - Groups
    
    func saveGroups(_ groups: [Group], for specialtyId: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(groups) {
            defaults.set(encoded, forKey: Keys.cachedGroups + specialtyId)
            defaults.set(Date(), forKey: Keys.lastUpdateTime + "groups_" + specialtyId)
        }
    }
    
    func loadGroups(for specialtyId: String) -> [Group]? {
        guard let data = defaults.data(forKey: Keys.cachedGroups + specialtyId),
              let groups = try? JSONDecoder().decode([Group].self, from: data) else {
            return nil
        }
        return groups
    }
    
    // MARK: - Schedule
    
    func saveSchedule(_ schedules: [DaySchedule], for groupId: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(schedules) {
            defaults.set(encoded, forKey: Keys.cachedSchedule + groupId)
            defaults.set(Date(), forKey: Keys.lastUpdateTime + "schedule_" + groupId)
        }
    }
    
    func loadSchedule(for groupId: String) -> [DaySchedule]? {
        guard let data = defaults.data(forKey: Keys.cachedSchedule + groupId),
              let schedules = try? JSONDecoder().decode([DaySchedule].self, from: data) else {
            return nil
        }
        return schedules
    }
    
    // MARK: - Replacements
    
    func saveReplacements(_ replacements: ReplacementsResponse?, for groupId: String) {
        guard let replacements = replacements else {
            defaults.removeObject(forKey: Keys.cachedReplacements + groupId)
            return
        }
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(replacements) {
            defaults.set(encoded, forKey: Keys.cachedReplacements + groupId)
            defaults.set(Date(), forKey: Keys.lastUpdateTime + "replacements_" + groupId)
        }
    }
    
    func loadReplacements(for groupId: String) -> ReplacementsResponse? {
        guard let data = defaults.data(forKey: Keys.cachedReplacements + groupId),
              let replacements = try? JSONDecoder().decode(ReplacementsResponse.self, from: data) else {
            return nil
        }
        return replacements
    }
    
    // MARK: - Cache Age
    
    func getCacheAge(for key: String) -> TimeInterval? {
        guard let lastUpdate = defaults.object(forKey: Keys.lastUpdateTime + key) as? Date else {
            return nil
        }
        return Date().timeIntervalSince(lastUpdate)
    }
    
    // Проверка: кеш свежий? (менее 24 часов)
    func isCacheFresh(for key: String) -> Bool {
        guard let age = getCacheAge(for: key) else { return false }
        return age < 24 * 60 * 60 // 24 часа
    }
}

