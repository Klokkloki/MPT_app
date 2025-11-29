import Foundation
import SwiftUI
import Combine

/// Сервис для управления рейтингом преподавателей
/// Голосование: Пн-Сб до 17:00 — открыто, после — закрыто до понедельника
/// Голоса накапливаются и НЕ обнуляются
@MainActor
class TeacherRatingService: ObservableObject {
    static let shared = TeacherRatingService()
    
    @Published private(set) var ratings: [TeacherRating] = []
    @Published private(set) var isVotingOpen: Bool = true
    @Published private(set) var votingClosesAt: Date?
    @Published private(set) var votingOpensAt: Date?
    
    private let defaults = UserDefaults.standard
    private let ratingsKey = "teacher_ratings_v3"
    private let votesKey = "user_votes_v3"
    
    private var votingCheckTimer: Timer?
    
    private init() {
        loadRatings()
        updateVotingStatus()
        startVotingStatusTimer()
    }
    
    deinit {
        votingCheckTimer?.invalidate()
    }
    
    // MARK: - Voting Schedule Logic
    
    /// Проверяет, открыто ли голосование
    /// Голосование открыто: Понедельник 00:00 — Суббота 17:00
    /// Голосование закрыто: Суббота 17:00 — Воскресенье 23:59
    private func updateVotingStatus() {
        let calendar = Calendar.current
        let now = Date()
        
        let weekday = calendar.component(.weekday, from: now) // 1=Вс, 2=Пн, ..., 7=Сб
        let hour = calendar.component(.hour, from: now)
        
        // Суббота (7) после 17:00 или Воскресенье (1) — голосование закрыто
        if weekday == 7 && hour >= 17 {
            isVotingOpen = false
            // Следующее открытие — понедельник 00:00
            votingOpensAt = nextMonday()
            votingClosesAt = nil
        } else if weekday == 1 {
            isVotingOpen = false
            // Следующее открытие — понедельник 00:00
            votingOpensAt = nextMonday()
            votingClosesAt = nil
        } else {
            isVotingOpen = true
            votingOpensAt = nil
            // Закрытие — суббота 17:00
            votingClosesAt = nextSaturday17()
        }
    }
    
    /// Возвращает дату следующего понедельника 00:00
    private func nextMonday() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = 2 // Понедельник
        components.hour = 0
        components.minute = 0
        
        if let monday = calendar.date(from: components), monday > now {
            return monday
        }
        
        // Если сегодня понедельник или позже, берём следующую неделю
        components.weekOfYear = (components.weekOfYear ?? 0) + 1
        return calendar.date(from: components) ?? now
    }
    
    /// Возвращает дату ближайшей субботы 17:00
    private func nextSaturday17() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        let weekday = calendar.component(.weekday, from: now)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.day = (components.day ?? 0) + (daysUntilSaturday == 0 ? 7 : daysUntilSaturday)
        components.hour = 17
        components.minute = 0
        
        if let saturday = calendar.date(from: components), saturday > now {
            return saturday
        }
        
        // Текущая суббота уже прошла
        components.day = (components.day ?? 0) + 7
        return calendar.date(from: components) ?? now
    }
    
    /// Запускает таймер для проверки статуса голосования
    private func startVotingStatusTimer() {
        votingCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateVotingStatus()
            }
        }
    }
    
    // MARK: - Load Ratings
    
    func loadRatings() {
        guard let data = defaults.data(forKey: ratingsKey),
              let loadedRatings = try? JSONDecoder().decode([TeacherRating].self, from: data) else {
            ratings = []
            return
        }
        
        // Загружаем голоса пользователя
        let userVotes = loadUserVotes()
        
        // Обновляем userVote для каждого рейтинга
        ratings = loadedRatings.map { rating in
            var updated = rating
            updated.userVote = userVotes[rating.teacherName]
            return updated
        }
    }
    
    // MARK: - Save Ratings
    
    private func saveRatingsToStorage() {
        // Сохраняем без userVote (он хранится отдельно)
        let ratingsToSave = ratings.map { rating in
            TeacherRating(
                id: rating.id,
                teacherName: rating.teacherName,
                likes: rating.likes,
                neutrals: rating.neutrals,
                dislikes: rating.dislikes,
                userVote: nil,
                weekStartDate: rating.weekStartDate
            )
        }
        
        if let encoded = try? JSONEncoder().encode(ratingsToSave) {
            defaults.set(encoded, forKey: ratingsKey)
        }
    }
    
    // MARK: - Vote
    
    /// Можно ли сейчас голосовать
    var canVote: Bool {
        return isVotingOpen
    }
    
    /// Режим тестирования: true = можно ставить много голосов (для проверки)
    /// Установите false для продакшена
    static let testingMode = false
    
    func vote(for teacherName: String, vote: VoteType) {
        // Проверяем, открыто ли голосование
        guard isVotingOpen else { return }
        
        var userVotes = loadUserVotes()
        
        // Находим или создаём рейтинг
        var ratingIndex = ratings.firstIndex(where: { $0.teacherName == teacherName })
        
        if ratingIndex == nil {
            let newRating = TeacherRating(teacherName: teacherName)
            ratings.append(newRating)
            ratingIndex = ratings.count - 1
        }
        
        guard let index = ratingIndex else { return }
        var rating = ratings[index]
        
        // В режиме тестирования — просто добавляем голос
        // В продакшене — учитываем предыдущий голос
        if !Self.testingMode {
            // Убираем предыдущий голос если был
            if let previousVote = userVotes[teacherName] {
                switch previousVote {
                case .like:
                    rating.likes = max(0, rating.likes - 1)
                case .neutral:
                    rating.neutrals = max(0, rating.neutrals - 1)
                case .dislike:
                    rating.dislikes = max(0, rating.dislikes - 1)
                }
            }
        }
        
        // Добавляем голос
        switch vote {
        case .like:
            rating.likes += 1
        case .neutral:
            rating.neutrals += 1
        case .dislike:
            rating.dislikes += 1
        }
        
        rating.userVote = vote
        ratings[index] = rating
        
        // Сохраняем
        saveRatingsToStorage()
        userVotes[teacherName] = vote
        saveUserVotes(userVotes)
    }
    
    func removeVote(for teacherName: String) {
        // В тестовом режиме — не удаляем голоса, просто убираем подсветку
        guard isVotingOpen else { return }
        
        var userVotes = loadUserVotes()
        
        guard let index = ratings.firstIndex(where: { $0.teacherName == teacherName }) else {
            return
        }
        
        var rating = ratings[index]
        
        // В режиме тестирования — не убираем голос, только снимаем подсветку
        if !Self.testingMode {
            if let previousVote = userVotes[teacherName] {
                switch previousVote {
                case .like:
                    rating.likes = max(0, rating.likes - 1)
                case .neutral:
                    rating.neutrals = max(0, rating.neutrals - 1)
                case .dislike:
                    rating.dislikes = max(0, rating.dislikes - 1)
                }
            }
        }
        
        rating.userVote = nil
        ratings[index] = rating
        
        saveRatingsToStorage()
        userVotes.removeValue(forKey: teacherName)
        saveUserVotes(userVotes)
    }
    
    // MARK: - Sorted Lists
    
    /// Все преподаватели, отсортированные по рейтингу (лучшие сверху)
    var sortedByBest: [TeacherRating] {
        ratings.sorted { $0.sortScore > $1.sortScore }
    }
    
    /// Топ-3 лучших преподавателей
    var top3: [TeacherRating] {
        Array(sortedByBest.filter { $0.totalVotes > 0 }.prefix(3))
    }
    
    /// Топ-10 лучших преподавателей (исключая топ-3)
    var top10: [TeacherRating] {
        let filtered = sortedByBest.filter { $0.totalVotes > 0 }
        guard filtered.count > 3 else { return [] }
        return Array(filtered.dropFirst(3).prefix(7))
    }
    
    /// Худшие преподаватели (с наибольшим количеством дизлайков)
    var worst: [TeacherRating] {
        ratings
            .filter { $0.dislikes > 0 }
            .sorted { $0.dislikes > $1.dislikes }
    }
    
    /// Остальные преподаватели (без голосов или средние)
    var middle: [TeacherRating] {
        let topIds = Set((top3 + top10).map { $0.id })
        let worstIds = Set(worst.map { $0.id })
        
        return ratings
            .filter { !topIds.contains($0.id) && !worstIds.contains($0.id) }
            .sorted { $0.teacherName < $1.teacherName }
    }
    
    // MARK: - User Votes
    
    private func loadUserVotes() -> [String: VoteType] {
        guard let data = defaults.data(forKey: votesKey),
              let votes = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        
        return votes.compactMapValues { VoteType(rawValue: $0) }
    }
    
    private func saveUserVotes(_ votes: [String: VoteType]) {
        let votesToSave = votes.mapValues { $0.rawValue }
        if let encoded = try? JSONEncoder().encode(votesToSave) {
            defaults.set(encoded, forKey: votesKey)
        }
    }
    
    // MARK: - Extract Teachers from Schedule
    
    /// Извлекает преподавателей из расписания и добавляет их в рейтинг
    /// Разделяет строки вида "А.А. Иванов, Б.Б. Петров" на отдельных преподавателей
    func extractAndAddTeachers(from schedules: [DaySchedule]) {
        var teacherNames = Set<String>()
        
        for schedule in schedules {
            for lesson in schedule.lessons {
                // Разделяем преподавателей по запятым
                let teachers = parseTeacherNames(lesson.teacher)
                teacherNames.formUnion(teachers)
                
                if let teacherDenom = lesson.teacherDenominator {
                    let denomTeachers = parseTeacherNames(teacherDenom)
                    teacherNames.formUnion(denomTeachers)
                }
            }
        }
        
        // Добавляем новых преподавателей в рейтинг
        let existingNames = Set(ratings.map { $0.teacherName })
        
        for name in teacherNames where !existingNames.contains(name) && !name.isEmpty {
            let newRating = TeacherRating(teacherName: name)
            ratings.append(newRating)
        }
        
        saveRatingsToStorage()
    }
    
    /// Парсит строку с преподавателями, разделяя по запятым
    /// "А.А. Иванов, Б.Б. Петров" -> ["А.А. Иванов", "Б.Б. Петров"]
    private func parseTeacherNames(_ input: String) -> [String] {
        return input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - UI Helpers
    
    /// Статус голосования для отображения
    var votingStatusText: String {
        if isVotingOpen {
            return "Голосование открыто"
        } else {
            return "Голосование закрыто"
        }
    }
    
    /// Время до события (открытия или закрытия)
    var timeUntilEventText: String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, HH:mm"
        
        if let closesAt = votingClosesAt {
            return "до \(formatter.string(from: closesAt))"
        } else if let opensAt = votingOpensAt {
            return "откроется \(formatter.string(from: opensAt))"
        }
        return nil
    }
    
    // MARK: - Load All Teachers (Статический список)
    
    /// Загружает всех преподавателей из статического списка (единоразово спаршено)
    func loadAllTeachers() {
        let existingNames = Set(ratings.map { $0.teacherName })
        var added = 0
        
        for name in Self.allTeacherNames where !existingNames.contains(name) {
            let newRating = TeacherRating(teacherName: name)
            ratings.append(newRating)
            added += 1
        }
        
        if added > 0 {
            saveRatingsToStorage()
            print("Добавлено \(added) новых преподавателей. Всего: \(ratings.count)")
        }
    }
    
    /// Сбрасывает все голоса (обнуляет рейтинги)
    func resetAllRatings() {
        // Обнуляем голоса у всех преподавателей
        ratings = ratings.map { rating in
            TeacherRating(
                id: rating.id,
                teacherName: rating.teacherName,
                likes: 0,
                neutrals: 0,
                dislikes: 0,
                userVote: nil,
                weekStartDate: rating.weekStartDate
            )
        }
        
        // Очищаем голоса пользователя
        defaults.removeObject(forKey: votesKey)
        
        // Сохраняем обнулённые рейтинги
        saveRatingsToStorage()
        
        print("Все рейтинги сброшены. Преподавателей: \(ratings.count)")
    }
    
    // MARK: - Статический список всех преподавателей (спаршено с mpt.ru)
    
    static let allTeacherNames: [String] = [
        "А.А. Зубенко", "А.А. Комаров", "А.А. Никонова", "А.А. Пучков", "А.А. Сердцева",
        "А.А. Шимбирёв", "А.А. Яковлева", "А.В. Андрюков", "А.В. Аскольский", "А.В. Гальцев",
        "А.В. Карцева", "А.В. Павлова", "А.В. Попова", "А.В. Соколова", "А.В. Ягофарова",
        "А.Д. Завьялова", "А.К. Азизов", "А.Л. Лосикова", "А.М. Проходцева", "А.М. Ченцов",
        "А.Н. Вилков", "А.О. Герлах", "А.Р. Каминьски", "А.Р. Судоплатов", "А.С. Ошкинис",
        "А.Ю. Дымская", "Б.М. Двораковский", "В.А. Колмыкова", "В.А. Николаев", "В.А. Чибук",
        "В.В. Григорьев", "В.В. Колесникович", "В.В. Познахирко", "В.В. Положков", "В.Е. Арутюнов",
        "В.Е. Терешков", "В.И. Ключник", "В.О. Никишин", "В.С. Прищеп", "Г.Н. Киселев",
        "Д.А. Клопов", "Д.А. Слабко", "Д.А. Шапошникова", "Д.Б. Магомедов", "Д.В. Серяк",
        "Д.В. Чекан", "Д.Г. Юдин", "Д.Д. Голубев", "Д.Е. Морозиков", "Д.И. Бакушкин",
        "Д.И. Здор", "Д.М. Готовец", "Д.М. Овчинников", "Д.Р. Белова", "Д.С. Галактионов",
        "Д.С. Городецкая", "Е.А. Ермашенко", "Е.А. Селиверстова", "Е.Б. Черемисина", "Е.В. Афанасьева",
        "Е.В. Добрынина", "Е.И. Исаева", "Е.М. Кретова", "Е.М. Парамонова", "Е.С. Попешкина",
        "Е.Ю. Бойцова", "И.А. Блинов", "И.А. Носова", "И.И. Головин", "И.О. Германюк",
        "И.Ю. Ермачкова", "К.А. Липатова", "К.А. Перевалов", "К.В. Мотыльков", "К.В. Стасевич",
        "К.П. Кравчук", "К.Р. Асейкина", "К.Р. Маслова", "К.С. Образцова", "Л.А. Чернышова",
        "Л.В. Бегунова", "Л.В. Дробышева", "Л.Г. Осипян", "Л.Ю. Попова", "М.А. Горбунова",
        "М.А. Злобина", "М.А. Кульгавов", "М.А. Саргсян", "М.А. Сущенко", "М.В. Горбутова",
        "М.В. Синдикаев", "М.В. Черемных", "М.М. Клемина", "М.Н. Дроздов", "М.Н. Кирюхина",
        "М.С. Гуленков", "М.С. Николаенко", "М.С. Прищеп", "Н.А. Андреева", "Н.А. Кульчинская",
        "Н.А. Митюшина", "Н.А. Шведова", "Н.А. Юрченко", "Н.В. Белоусова", "Н.В. Бибикова",
        "Н.Г. Николаева", "Н.Е. Ключник", "Н.Е. Петкова", "Н.Р. Абакарова", "Н.С. Кузнецова",
        "Н.С. Лапонкин", "О.А. Водопьянова", "О.А. Евдокименко", "О.В. Кручинина", "О.Л. Мещеринова",
        "О.Н. Кирюхина", "О.Н. Ридигер", "О.Н. Шестакова", "О.О. Токарчук", "П.А. Елистратова",
        "П.А. Майкова", "П.В. Агафонов", "П.О. Кузнецов", "Р.Д. Степаньков", "Р.Ю. Волков",
        "С.А. Абрамов", "С.А. Вериго", "С.А. Журкин", "С.А. Куртева", "С.В. Виноградов",
        "С.В. Караваев", "С.В. Потякина", "С.Н. Васина", "С.П. Кицына", "С.П. Митрофанова",
        "С.С. Андрианова", "С.С. Иконникова", "Т.И. Позднякова", "Э.В. Голеусова", "Э.Ш. Хисяметдинова",
        "Ю.А. Калашникова", "Ю.В. Ефимова", "Ю.В. Мамошкина", "Ю.И. Володина", "Ю.И. Кортукова",
        "Ю.О. Нелюбов", "Я.А. Климова", "Я.В. Михайлова"
    ]
}
