import Foundation
import SwiftUI

// MARK: - Domain Models

struct Specialty: Identifiable, Hashable, Codable {
    let id: String          // tab_id для API (e.g. "69d898df1add22061438dbc8ff0a73fa")
    let name: String        // e.g. "09.02.01 Э"
}

struct Group: Identifiable, Hashable, Codable {
    let id: String          // e.g. "Э-1-22, Э-11/1-23"
    let name: String        // same as id for display
    let specialtyId: String // tab_id специальности
}

struct Lesson: Identifiable, Hashable, Codable {
    let id: UUID
    let number: Int                 // 1..7
    let title: String               // Предмет (числитель или основной)
    let teacher: String             // Преподаватель (числитель или основной)
    let location: String
    let campus: String              // e.g. "Нахимовский", "Нежинская"
    let startTime: String           // "08:30"
    let endTime: String             // "10:00"
    let isReplacement: Bool
    let originalTitle: String?
    let date: Date?                 // Дата урока для создания стабильного ID
    
    // Для сдвоенных пар (числитель/знаменатель)
    let titleDenominator: String?   // Предмет для знаменателя (если отличается)
    let teacherDenominator: String? // Преподаватель для знаменателя (если отличается)
    
    // Проверка: это сдвоенная пара?
    var hasDenominator: Bool {
        titleDenominator != nil && !titleDenominator!.isEmpty
    }
    
    // ID для знаменателя (для отдельного ДЗ)
    var denominatorId: UUID {
        // Генерируем отдельный ID для знаменателя
        let dateString = date.map { 
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: $0)
        } ?? ""
        let combined = "\(number)-\(titleDenominator ?? "")-\(teacherDenominator ?? "")-\(startTime)-\(endTime)-\(campus)-\(dateString)-denominator"
        var hash: UInt64 = 5381
        for char in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        let part1 = UInt32(hash & 0xffffffff)
        let part2 = UInt16((hash >> 32) & 0xffff)
        let part3 = UInt16((hash >> 48) & 0xffff)
        let part4 = UInt16((hash >> 16) & 0xffff)
        let part5 = hash & 0xffffffffffff
        let uuidString = String(format: "%08x-%04x-%04x-%04x-%012llx", part1, part2, part3, part4, part5)
        return UUID(uuidString: uuidString) ?? UUID()
    }
    
    init(id: UUID? = nil, number: Int, title: String, teacher: String, location: String, campus: String, startTime: String, endTime: String, isReplacement: Bool, originalTitle: String?, date: Date? = nil, titleDenominator: String? = nil, teacherDenominator: String? = nil) {
        // Создаём стабильный ID на основе характеристик урока
        if let providedId = id {
            self.id = providedId
        } else {
            // Генерируем UUID на основе характеристик для стабильности
            let dateString = date.map { 
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: $0)
            } ?? ""
            let combined = "\(number)-\(title)-\(teacher)-\(startTime)-\(endTime)-\(campus)-\(dateString)"
            var hash: UInt64 = 5381
            for char in combined.utf8 {
                hash = ((hash << 5) &+ hash) &+ UInt64(char)
            }
            // Создаём UUID из хеша (формат: 8-4-4-4-12)
            let part1 = UInt32(hash & 0xffffffff)
            let part2 = UInt16((hash >> 32) & 0xffff)
            let part3 = UInt16((hash >> 48) & 0xffff)
            let part4 = UInt16((hash >> 16) & 0xffff)
            let part5 = hash & 0xffffffffffff
            let uuidString = String(format: "%08x-%04x-%04x-%04x-%012llx", part1, part2, part3, part4, part5)
            self.id = UUID(uuidString: uuidString) ?? UUID()
        }
        self.number = number
        self.title = title
        self.teacher = teacher
        self.location = location
        self.campus = campus
        self.startTime = startTime
        self.endTime = endTime
        self.isReplacement = isReplacement
        self.originalTitle = originalTitle
        self.date = date
        self.titleDenominator = titleDenominator
        self.teacherDenominator = teacherDenominator
    }
}

struct DaySchedule: Identifiable, Hashable, Codable {
    let id: UUID
    let date: Date
    let lessons: [Lesson]
    let replacements: [Lesson]      // заменённые пары на этот день
    var isDayOff: Bool = false      // выходной день
    
    init(id: UUID = UUID(), date: Date, lessons: [Lesson], replacements: [Lesson], isDayOff: Bool = false) {
        self.id = id
        self.date = date
        self.lessons = lessons
        self.replacements = replacements
        self.isDayOff = isDayOff
    }
}

struct Homework: Identifiable, Hashable, Codable {
    let id: UUID
    let lessonId: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var shouldRemind: Bool
    var isCompleted: Bool = false
}

struct DayNote: Identifiable, Hashable {
    let id: UUID = UUID()
    let date: Date
    var text: String
    var createdAt: Date = Date()
}

// MARK: - Week Info

struct WeekInfo: Codable {
    let date: String              // "27 Ноября - Четверг"
    let weekType: WeekType        // numerator или denominator
    let weekTypeRu: String        // "Числитель" или "Знаменатель"
}

enum WeekType: String, Codable {
    case numerator = "numerator"
    case denominator = "denominator"
    
    var displayName: String {
        switch self {
        case .numerator: return "Числитель"
        case .denominator: return "Знаменатель"
        }
    }
}

// MARK: - Замены

struct Replacement: Identifiable, Hashable, Codable {
    let id: UUID
    let pairNumber: Int           // Номер пары
    let originalSubject: String   // Что заменяют
    let newSubject: String        // На что заменяют
    let addedAt: String           // Когда добавлена
    
    init(id: UUID = UUID(), pairNumber: Int, originalSubject: String, newSubject: String, addedAt: String) {
        self.id = id
        self.pairNumber = pairNumber
        self.originalSubject = originalSubject
        self.newSubject = newSubject
        self.addedAt = addedAt
    }
    
    // Проверка: это отмена занятия?
    var isCancelled: Bool {
        newSubject.lowercased().contains("отменено")
    }
    
    // Проверка: это перенос?
    var isTransfer: Bool {
        newSubject.lowercased().contains("перенесено")
    }
}

struct GroupReplacements: Identifiable, Hashable, Codable {
    let id: UUID
    let groupName: String
    let replacements: [Replacement]
    
    init(id: UUID = UUID(), groupName: String, replacements: [Replacement]) {
        self.id = id
        self.groupName = groupName
        self.replacements = replacements
    }
}

struct DayReplacements: Identifiable, Hashable, Codable {
    let id: UUID
    let date: String              // "28.11.2025"
    let dateDisplay: String       // "28 Ноября"
    let isToday: Bool
    let groups: [GroupReplacements]
    
    init(id: UUID = UUID(), date: String, dateDisplay: String, isToday: Bool, groups: [GroupReplacements]) {
        self.id = id
        self.date = date
        self.dateDisplay = dateDisplay
        self.isToday = isToday
        self.groups = groups
    }
}

struct ReplacementsResponse: Hashable, Codable {
    let days: [DayReplacements]
    
    // Есть ли замены вообще
    var hasReplacements: Bool {
        !days.isEmpty && days.contains { !$0.groups.isEmpty }
    }
}

// MARK: - Mock Data (для разработки без сервера)

enum MockData {
    static let specialties: [Specialty] = [
        .init(id: "mock_09.02.01", name: "09.02.01 Э"),
        .init(id: "mock_09.02.06", name: "09.02.06 СА"),
        .init(id: "mock_09.02.07_1", name: "09.02.07 П,Т"),
        .init(id: "mock_25.02.08", name: "25.02.08 БАС"),
        .init(id: "mock_10.02.05", name: "10.02.05 БИ"),
        .init(id: "mock_09.02.07_2", name: "09.02.07 ИС, БД, ВД"),
        .init(id: "mock_40.02.01", name: "40.02.01, 40.02.04 Ю"),
        .init(id: "mock_09.02.09", name: "09.02.09 ВТ")
    ]

    static let groups: [Group] = [
        .init(id: "Э-1-22, Э-11/1-23", name: "Э-1-22, Э-11/1-23", specialtyId: "mock_09.02.01"),
        .init(id: "Э-1-24; Э-11/1-25", name: "Э-1-24; Э-11/1-25", specialtyId: "mock_09.02.01"),
        .init(id: "Э-2-23", name: "Э-2-23", specialtyId: "mock_09.02.01"),
        .init(id: "СА-2-24", name: "СА-2-24", specialtyId: "mock_09.02.06"),
        .init(id: "СА-2-23", name: "СА-2-23", specialtyId: "mock_09.02.06"),
        .init(id: "БИ50-4-23", name: "БИ50-4-23", specialtyId: "mock_10.02.05")
    ]

    static func todaySchedule(for group: Group, date: Date = Date()) -> DaySchedule {
        let lessons: [Lesson] = [
            .init(
                number: 3,
                title: "Электроника и схемотехника",
                teacher: "Л.В. Дробышева",
                location: "Нахимовский, ауд. 301",
                campus: "Нахимовский",
                startTime: "12:00",
                endTime: "13:30",
                isReplacement: false,
                originalTitle: nil,
                date: date
            ),
            .init(
                number: 4,
                title: "Иностранный язык в профессиональной деятельности",
                teacher: "А.А. Сердцева, П.А. Майкова",
                location: "Нахимовский, ауд. 214",
                campus: "Нахимовский",
                startTime: "13:50",
                endTime: "15:20",
                isReplacement: false,
                originalTitle: nil,
                date: date
            ),
            .init(
                number: 5,
                title: "Криптографические средства защиты информации",
                teacher: "Д.Д. Голубев",
                location: "Нахимовский, ауд. 410",
                campus: "Нахимовский",
                startTime: "15:30",
                endTime: "17:00",
                isReplacement: false,
                originalTitle: nil,
                date: date
            )
        ]

        let replacements: [Lesson] = [
            .init(
                number: 5,
                title: "Криптографические средства защиты информации",
                teacher: "Д.Д. Голубев",
                location: "Нахимовский, ауд. 410",
                campus: "Нахимовский",
                startTime: "15:30",
                endTime: "17:00",
                isReplacement: true,
                originalTitle: "Основы алгоритмизации и программирования",
                date: date
            )
        ]

        return DaySchedule(date: date, lessons: lessons, replacements: replacements)
    }

    static let bells: [(pair: Int, time: String, breakDescription: String)] = [
        (1, "08:30 – 10:00", "Перемена 10 минут"),
        (2, "10:10 – 11:40", "Перемена 20 минут"),
        (3, "12:00 – 13:30", "Перемена 20 минут"),
        (4, "13:50 – 15:20", "Перемена 10 минут"),
        (5, "15:30 – 17:00", "Перемена 5 минут"),
        (6, "17:05 – 18:35", "Перемена 5 минут"),
        (7, "18:40 – 20:10", "Перемена 0 минут")
    ]
}

// MARK: - Teacher Rating (Рейтинг преподавателей)

struct TeacherRating: Identifiable, Hashable, Codable {
    let id: UUID
    let teacherName: String
    var likes: Int          // Положительные голоса
    var neutrals: Int       // Нейтральные голоса (+/-)
    var dislikes: Int       // Отрицательные голоса
    var userVote: VoteType? // Голос текущего пользователя
    var weekStartDate: Date // Дата начала текущей недели (для сброса)
    
    /// Рейтинг: лайки дают +1, нейтральные +0.5, дизлайки +0
    /// Формула: (likes + neutrals*0.5) / totalVotes
    var score: Double {
        let total = totalVotes
        guard total > 0 else { return 0.5 }
        return (Double(likes) + Double(neutrals) * 0.5) / Double(total)
    }
    
    /// Общее количество голосов
    var totalVotes: Int {
        likes + neutrals + dislikes
    }
    
    /// Балл для сортировки (от -100 до +100)
    var sortScore: Int {
        guard totalVotes > 0 else { return 0 }
        return likes - dislikes
    }
    
    /// Процент положительных оценок
    var positivePercent: Int {
        guard totalVotes > 0 else { return 50 }
        return Int((Double(likes) / Double(totalVotes)) * 100)
    }
    
    init(id: UUID = UUID(), teacherName: String, likes: Int = 0, neutrals: Int = 0, dislikes: Int = 0, userVote: VoteType? = nil, weekStartDate: Date? = nil) {
        self.id = id
        self.teacherName = teacherName
        self.likes = likes
        self.neutrals = neutrals
        self.dislikes = dislikes
        self.userVote = userVote
        self.weekStartDate = weekStartDate ?? TeacherRating.currentWeekStart()
    }
    
    /// Возвращает понедельник текущей недели
    static func currentWeekStart() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        return calendar.date(from: components) ?? today
    }
}

enum VoteType: String, Codable, CaseIterable {
    case like = "like"
    case neutral = "neutral"
    case dislike = "dislike"
    
    var icon: String {
        switch self {
        case .like: return "hand.thumbsup.fill"
        case .neutral: return "plusminus"
        case .dislike: return "hand.thumbsdown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .like: return .green
        case .neutral: return .yellow
        case .dislike: return .red
        }
    }
}

// MARK: - Advertisement (Реклама/Рекомендации)

struct Advertisement: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let subtitle: String?        // Короткое описание (1 строка)
    let description: String      // Полное описание (для раскрытой карточки)
    let iconUrl: String?         // URL иконки с сервера
    let iconName: String?        // Имя иконки в Assets (fallback)
    let iconEmoji: String?       // Эмодзи как иконка (fallback)
    let url: String?             // Ссылка для перехода
    let category: AdCategory
    let tags: [String]?          // Теги: "бесплатно", "скидка", "новое"
    let gradientColors: [String]? // Цвета градиента для карточки
    let isPinned: Bool           // Закреплённая реклама (показывается первой)
    
    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        description: String,
        iconUrl: String? = nil,
        iconName: String? = nil,
        iconEmoji: String? = nil,
        url: String? = nil,
        category: AdCategory,
        tags: [String]? = nil,
        gradientColors: [String]? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.iconUrl = iconUrl
        self.iconName = iconName
        self.iconEmoji = iconEmoji
        self.url = url
        self.category = category
        self.tags = tags
        self.gradientColors = gradientColors
        self.isPinned = isPinned
    }
    
    // Для обратной совместимости
    var imageName: String? { iconName }
}

enum AdCategory: String, Codable, CaseIterable {
    case course = "course"
    case onlineSchool = "onlineSchool"
    case telegram = "telegram"
    case youtube = "youtube"
    case service = "service"
    case event = "event"
    
    var displayName: String {
        switch self {
        case .course: return "Курсы"
        case .onlineSchool: return "Онлайн-школы"
        case .telegram: return "Telegram"
        case .youtube: return "YouTube"
        case .service: return "Сервисы"
        case .event: return "События"
        }
    }
    
    var icon: String {
        switch self {
        case .course: return "book.fill"
        case .onlineSchool: return "graduationcap.fill"
        case .telegram: return "paperplane.fill"
        case .youtube: return "play.rectangle.fill"
        case .service: return "wrench.and.screwdriver.fill"
        case .event: return "calendar.badge.clock"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .course: return .blue
        case .onlineSchool: return .purple
        case .telegram: return .cyan
        case .youtube: return .red
        case .service: return .orange
        case .event: return .green
        }
    }
}

// MARK: - News Item (Новости/Фотографии)

struct NewsItem: Identifiable, Hashable, Codable {
    let id: UUID
    let imageName: String  // Имя файла в Bundle (например, "00.10.2024")
    let title: String?     // Опциональный заголовок
    let description: String? // Опциональное описание
    
    init(id: UUID = UUID(), imageName: String, title: String? = nil, description: String? = nil) {
        self.id = id
        self.imageName = imageName
        self.title = title
        self.description = description
    }
}

// MARK: - Resource Collections (Подборки ресурсов)

struct ResourceCollection: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let subtitle: String?
    let category: String
    let gradientColors: [String]?
    let isPinned: Bool
    let resources: [Resource]
    
    init(id: String, title: String, subtitle: String? = nil, category: String, gradientColors: [String]? = nil, isPinned: Bool = false, resources: [Resource] = []) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.category = category
        self.gradientColors = gradientColors
        self.isPinned = isPinned
        self.resources = resources
    }
}

struct Resource: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let description: String?
    let url: String
    let icon: String?
    let subscribers: String?
    
    init(id: String, title: String, description: String? = nil, url: String, icon: String? = nil, subscribers: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.icon = icon
        self.subscribers = subscribers
    }
}
