import Foundation

// MARK: - API Response Models

struct APIWeekInfo: Codable {
    let date: String
    let weekType: String
    let weekTypeRu: String
    
    enum CodingKeys: String, CodingKey {
        case date
        case weekType = "week_type"
        case weekTypeRu = "week_type_ru"
    }
}

struct APISpecialty: Codable, Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let fullName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, code, name
        case fullName = "full_name"
    }
}

struct APIGroup: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let specialtyId: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case specialtyId = "specialty_id"
    }
}

struct APILesson: Codable {
    let number: Int
    let subject: String
    let teacher: String
    let subjectDenominator: String?
    let teacherDenominator: String?
    
    enum CodingKeys: String, CodingKey {
        case number, subject, teacher
        case subjectDenominator = "subject_denominator"
        case teacherDenominator = "teacher_denominator"
    }
}

struct APIDaySchedule: Codable {
    let day: String
    let dayIndex: Int
    let campus: String?
    let lessons: [APILesson]
    let isDayOff: Bool
    
    enum CodingKeys: String, CodingKey {
        case day
        case dayIndex = "day_index"
        case campus, lessons
        case isDayOff = "is_day_off"
    }
}

struct APIWeekSchedule: Codable {
    let group: String
    let specialtyId: String
    let days: [APIDaySchedule]
    
    enum CodingKeys: String, CodingKey {
        case group
        case specialtyId = "specialty_id"
        case days
    }
}

struct APIScheduleResponse: Codable {
    let weekInfo: APIWeekInfo
    let schedule: APIWeekSchedule
    
    enum CodingKeys: String, CodingKey {
        case weekInfo = "week_info"
        case schedule
    }
}

// MARK: - API Replacements Models

struct APIReplacement: Codable {
    let pairNumber: Int
    let originalSubject: String
    let newSubject: String
    let addedAt: String
    
    enum CodingKeys: String, CodingKey {
        case pairNumber = "pair_number"
        case originalSubject = "original_subject"
        case newSubject = "new_subject"
        case addedAt = "added_at"
    }
}

struct APIGroupReplacements: Codable {
    let groupName: String
    let replacements: [APIReplacement]
    
    enum CodingKeys: String, CodingKey {
        case groupName = "group_name"
        case replacements
    }
}

struct APIDayReplacements: Codable {
    let date: String
    let dateDisplay: String
    let isToday: Bool
    let groups: [APIGroupReplacements]
    
    enum CodingKeys: String, CodingKey {
        case date
        case dateDisplay = "date_display"
        case isToday = "is_today"
        case groups
    }
}

struct APIReplacementsResponse: Codable {
    let days: [APIDayReplacements]
}

// MARK: - Network Service

actor NetworkService {
    static let shared = NetworkService()
    
    // ВАЖНО: Для работы на физическом iPhone используйте IP адрес вашего Mac
    // На Mac: Системные настройки → Сеть → Wi-Fi → IP адрес (например, 192.168.1.100)
    // Для симулятора: localhost
    // Для продакшена: замените на реальный URL сервера (например, https://api.mptapp.ru)
    
    // Используем Render.com для всех устройств (симулятор + физические устройства)
    // ЗАМЕНИТЕ на ваш реальный URL с Render.com (найди его в Dashboard)
    private let _baseURL = "https://mpt-app.onrender.com"
    
    var baseURL: String {
        return _baseURL
    }
    
    private init() {}
    
    // MARK: - Week Info
    
    func fetchWeekInfo() async throws -> APIWeekInfo {
        let url = URL(string: "\(_baseURL)/api/week-info")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(APIWeekInfo.self, from: data)
    }
    
    // MARK: - Specialties
    
    func fetchSpecialties() async throws -> [APISpecialty] {
        let url = URL(string: "\(_baseURL)/api/specialties")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([APISpecialty].self, from: data)
    }
    
    // MARK: - Groups
    
    func fetchGroups(specialtyId: String) async throws -> [APIGroup] {
        var components = URLComponents(string: "\(_baseURL)/api/groups")!
        components.queryItems = [URLQueryItem(name: "specialty_id", value: specialtyId)]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode([APIGroup].self, from: data)
    }
    
    // MARK: - Schedule
    
    func fetchSchedule(group: String, specialtyId: String) async throws -> APIScheduleResponse {
        var components = URLComponents(string: "\(_baseURL)/api/schedule")!
        components.queryItems = [
            URLQueryItem(name: "group", value: group),
            URLQueryItem(name: "specialty_id", value: specialtyId)
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(APIScheduleResponse.self, from: data)
    }
    
    // MARK: - Replacements (Замены)
    
    func fetchReplacements(group: String? = nil) async throws -> APIReplacementsResponse {
        var components = URLComponents(string: "\(_baseURL)/api/replacements")!
        if let group = group {
            components.queryItems = [URLQueryItem(name: "group", value: group)]
        }
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(APIReplacementsResponse.self, from: data)
    }
    
    // MARK: - All Teachers (Все преподаватели)
    
    func fetchAllTeachers() async throws -> APITeachersResponse {
        let url = URL(string: "\(_baseURL)/api/teachers")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(APITeachersResponse.self, from: data)
    }
}

// MARK: - API Teachers Response

struct APITeachersResponse: Codable {
    let count: Int
    let teachers: [String]
}

// MARK: - Converters to App Models

extension APIScheduleResponse {
    /// Конвертирует API ответ в модели приложения
    func toDaySchedules() -> [DaySchedule] {
        let calendar = Calendar.current
        let today = Date()
        
        // Находим понедельник текущей недели
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        
        return schedule.days.map { apiDay in
            let dayDate = calendar.date(byAdding: .day, value: apiDay.dayIndex, to: monday)!
            
            let lessons: [Lesson] = apiDay.lessons.map { apiLesson in
                // Время пар
                let times = lessonTimes(for: apiLesson.number)
                
                // Передаём оба варианта (числитель и знаменатель) если есть
                return Lesson(
                    number: apiLesson.number,
                    title: apiLesson.subject,
                    teacher: apiLesson.teacher,
                    location: apiDay.campus ?? "",
                    campus: apiDay.campus ?? "",
                    startTime: times.start,
                    endTime: times.end,
                    isReplacement: false,
                    originalTitle: nil,
                    date: dayDate,
                    titleDenominator: apiLesson.subjectDenominator,
                    teacherDenominator: apiLesson.teacherDenominator
                )
            }
            
            return DaySchedule(
                date: dayDate,
                lessons: lessons,
                replacements: []
            )
        }
    }
    
    private func lessonTimes(for number: Int) -> (start: String, end: String) {
        switch number {
        case 1: return ("08:30", "10:00")
        case 2: return ("10:10", "11:40")
        case 3: return ("12:00", "13:30")
        case 4: return ("13:50", "15:20")
        case 5: return ("15:30", "17:00")
        case 6: return ("17:05", "18:35")
        case 7: return ("18:40", "20:10")
        default: return ("", "")
        }
    }
}

extension APISpecialty {
    func toSpecialty() -> Specialty {
        Specialty(id: id, name: name)
    }
}

extension APIGroup {
    func toGroup() -> Group {
        Group(id: id, name: name, specialtyId: specialtyId)
    }
}

// MARK: - Replacements Converter

extension APIReplacementsResponse {
    func toReplacementsResponse() -> ReplacementsResponse {
        ReplacementsResponse(
            days: days.map { apiDay in
                DayReplacements(
                    date: apiDay.date,
                    dateDisplay: apiDay.dateDisplay,
                    isToday: apiDay.isToday,
                    groups: apiDay.groups.map { apiGroup in
                        GroupReplacements(
                            groupName: apiGroup.groupName,
                            replacements: apiGroup.replacements.map { apiReplacement in
                                Replacement(
                                    pairNumber: apiReplacement.pairNumber,
                                    originalSubject: apiReplacement.originalSubject,
                                    newSubject: apiReplacement.newSubject,
                                    addedAt: apiReplacement.addedAt
                                )
                            }
                        )
                    }
                )
            }
        )
    }
}

