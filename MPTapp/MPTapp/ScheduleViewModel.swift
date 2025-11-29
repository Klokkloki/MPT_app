import Foundation
import SwiftUI

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var weekInfo: WeekInfo?
    @Published var specialties: [Specialty] = []
    @Published var groups: [Group] = []
    @Published var weekSchedules: [DaySchedule] = []
    @Published var replacements: ReplacementsResponse?
    @Published var isLoading = false
    @Published var isLoadingReplacements = false
    @Published var errorMessage: String?
    
    // Используем ли mock-данные (для разработки без сервера)
    @Published var useMockData = false
    
    // MARK: - Load Week Info
    
    func loadWeekInfo() async {
        if useMockData {
            weekInfo = WeekInfo(
                date: "27 Ноября - Четверг",
                weekType: .numerator,
                weekTypeRu: "Числитель"
            )
            return
        }
        
        // Сначала загружаем из кеша
        if let cached = StorageService.shared.loadWeekInfo() {
            weekInfo = cached
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let apiWeekInfo = try await NetworkService.shared.fetchWeekInfo()
            let newWeekInfo = WeekInfo(
                date: apiWeekInfo.date,
                weekType: WeekType(rawValue: apiWeekInfo.weekType) ?? .numerator,
                weekTypeRu: apiWeekInfo.weekTypeRu
            )
            weekInfo = newWeekInfo
            // Сохраняем в кеш
            StorageService.shared.saveWeekInfo(newWeekInfo)
        } catch {
            // Если нет интернета и нет кеша — показываем ошибку
            if weekInfo == nil {
                errorMessage = "Нет подключения к интернету. Используются сохранённые данные."
            } else {
                errorMessage = nil // Есть кеш, не показываем ошибку
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Load Specialties
    
    func loadSpecialties() async {
        if useMockData {
            specialties = MockData.specialties
            return
        }
        
        // Сначала загружаем из кеша
        if let cached = StorageService.shared.loadSpecialties() {
            specialties = cached
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let apiSpecialties = try await NetworkService.shared.fetchSpecialties()
            let newSpecialties = apiSpecialties.map { $0.toSpecialty() }
            specialties = newSpecialties
            // Сохраняем в кеш
            StorageService.shared.saveSpecialties(newSpecialties)
        } catch {
            // Если нет интернета и нет кеша — используем mock
            if specialties.isEmpty {
                errorMessage = "Нет подключения к интернету. Используются сохранённые данные."
                specialties = MockData.specialties
            } else {
                errorMessage = nil // Есть кеш, не показываем ошибку
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Load Groups
    
    func loadGroups(for specialty: Specialty) async {
        if useMockData {
            groups = MockData.groups.filter { $0.specialtyId == specialty.id }
            return
        }
        
        // Сначала загружаем из кеша
        if let cached = StorageService.shared.loadGroups(for: specialty.id) {
            groups = cached
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let apiGroups = try await NetworkService.shared.fetchGroups(specialtyId: specialty.id)
            let newGroups = apiGroups.map { $0.toGroup() }
            groups = newGroups
            // Сохраняем в кеш
            StorageService.shared.saveGroups(newGroups, for: specialty.id)
        } catch {
            // Если нет интернета и нет кеша — используем mock
            if groups.isEmpty {
                errorMessage = "Нет подключения к интернету. Используются сохранённые данные."
                groups = MockData.groups.filter { $0.specialtyId == specialty.id }
            } else {
                errorMessage = nil // Есть кеш, не показываем ошибку
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Load Schedule
    
    func loadSchedule(for group: Group) async {
        if useMockData {
            loadMockSchedule(for: group)
            return
        }
        
        // Сначала загружаем из кеша
        if let cached = StorageService.shared.loadSchedule(for: group.id) {
            weekSchedules = cached
            // Также загружаем weekInfo из кеша если есть
            if weekInfo == nil, let cachedWeekInfo = StorageService.shared.loadWeekInfo() {
                weekInfo = cachedWeekInfo
            }
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await NetworkService.shared.fetchSchedule(
                group: group.name,
                specialtyId: group.specialtyId
            )
            
            let currentWeekType = WeekType(rawValue: response.weekInfo.weekType) ?? .numerator
            let newSchedules = response.toDaySchedules()
            weekSchedules = newSchedules
            
            let newWeekInfo = WeekInfo(
                date: response.weekInfo.date,
                weekType: currentWeekType,
                weekTypeRu: response.weekInfo.weekTypeRu
            )
            weekInfo = newWeekInfo
            
            // Сохраняем в кеш
            StorageService.shared.saveSchedule(newSchedules, for: group.id)
            StorageService.shared.saveWeekInfo(newWeekInfo)
        } catch {
            // Если нет интернета и нет кеша — используем mock
            if weekSchedules.isEmpty {
                errorMessage = "Нет подключения к интернету. Используются сохранённые данные."
                loadMockSchedule(for: group)
            } else {
                errorMessage = nil // Есть кеш, не показываем ошибку
            }
        }
        
        isLoading = false
    }
    
    private func loadMockSchedule(for group: Group) {
        let calendar = Calendar.current
        let today = Date()
        
        // Находим понедельник текущей недели
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        
        weekSchedules = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: dayOffset, to: monday)!
            let currentWeekday = calendar.component(.weekday, from: date)
            
            if currentWeekday == 1 { // Воскресенье
                return DaySchedule(date: date, lessons: [], replacements: [], isDayOff: true)
            } else {
                return MockData.todaySchedule(for: group, date: date)
            }
        }
    }
    
    // MARK: - Get Today Schedule
    
    func getTodaySchedule(for group: Group) -> DaySchedule {
        return getSchedule(for: Date(), group: group)
    }
    
    // MARK: - Get Schedule for Date
    
    /// Возвращает расписание для конкретной даты.
    /// Расписание — это шаблон на неделю, который применяется к любой неделе.
    /// Находим расписание по дню недели (пн=0, вт=1, ..., сб=5, вс=6).
    func getSchedule(for date: Date, group: Group) -> DaySchedule {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Воскресенье — всегда выходной
        if weekday == 1 {
            return DaySchedule(date: date, lessons: [], replacements: [], isDayOff: true)
        }
        
        // Преобразуем weekday (1=вс, 2=пн, ..., 7=сб) в dayIndex (0=пн, ..., 5=сб)
        let dayIndex = (weekday + 5) % 7  // пн=0, вт=1, ср=2, чт=3, пт=4, сб=5
        
        // Ищем расписание по дню недели (dayIndex), а не по дате
        if let templateSchedule = weekSchedules.first(where: { templateDay in
            let templateWeekday = calendar.component(.weekday, from: templateDay.date)
            let templateDayIndex = (templateWeekday + 5) % 7
            return templateDayIndex == dayIndex
        }) {
            // Возвращаем копию с правильной датой и обновлёнными ID уроков
            return DaySchedule(
                date: date,
                lessons: templateSchedule.lessons.map { lesson in
                    Lesson(
                        number: lesson.number,
                        title: lesson.title,
                        teacher: lesson.teacher,
                        location: lesson.location,
                        campus: lesson.campus,
                        startTime: lesson.startTime,
                        endTime: lesson.endTime,
                        isReplacement: lesson.isReplacement,
                        originalTitle: lesson.originalTitle,
                        date: date,  // Важно: новая дата для стабильного ID
                        titleDenominator: lesson.titleDenominator,
                        teacherDenominator: lesson.teacherDenominator
                    )
                },
                replacements: [],  // Замены не переносятся на другие недели
                isDayOff: templateSchedule.isDayOff
            )
        }
        
        // Если расписание ещё не загружено — возвращаем пустой день
        return DaySchedule(date: date, lessons: [], replacements: [], isDayOff: false)
    }
    
    // MARK: - Load Replacements (Замены)
    
    func loadReplacements(for group: Group) async {
        if useMockData {
            replacements = nil
            return
        }
        
        // Сначала загружаем из кеша
        if let cached = StorageService.shared.loadReplacements(for: group.id) {
            replacements = cached
        }
        
        isLoadingReplacements = true
        
        do {
            let apiReplacements = try await NetworkService.shared.fetchReplacements(group: group.name)
            let newReplacements = apiReplacements.toReplacementsResponse()
            replacements = newReplacements
            // Сохраняем в кеш
            StorageService.shared.saveReplacements(newReplacements, for: group.id)
        } catch {
            // Не показываем ошибку — замены могут отсутствовать или использовать кеш
            // Если кеш есть, он уже загружен выше
        }
        
        isLoadingReplacements = false
    }
    
    // Проверяет есть ли замены на сегодня для группы
    var hasTodayReplacements: Bool {
        guard let replacements = replacements else { return false }
        return replacements.days.contains { $0.isToday && !$0.groups.isEmpty }
    }
    
    // Получает замены на сегодня
    var todayReplacements: [Replacement] {
        guard let replacements = replacements else { return [] }
        guard let today = replacements.days.first(where: { $0.isToday }) else { return [] }
        return today.groups.flatMap { $0.replacements }
    }
    
    // MARK: - Extract Teachers
    
    /// Извлекает всех преподавателей из расписания и добавляет их в рейтинг
    func extractAndCreateTeacherRatings() {
        TeacherRatingService.shared.extractAndAddTeachers(from: weekSchedules)
    }
}

