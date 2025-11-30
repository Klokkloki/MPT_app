import SwiftUI

// Тип урока для ДЗ (числитель или знаменатель)
enum LessonType {
    case numerator
    case denominator
}

struct TodayView: View {
    let group: Group
    @Binding var schedule: DaySchedule
    @Binding var homeworks: [UUID: Homework]  // key: lessonId
    @ObservedObject var viewModel: ScheduleViewModel
    @ObservedObject var appSettings = AppSettingsService.shared
    var onHomeworksChanged: (() -> Void)? = nil

    @State private var selectedLessonForHomework: Lesson?
    @State private var selectedLessonType: LessonType = .numerator
    @State private var currentBannerIndex: Int = 0
    @State private var selectedDayOffset: Int = 0  // 0 = сегодня, 1 = завтра, 2 = послезавтра
    
    // Рекламные баннеры (загружаются из папки news)
    private let banners: [NewsItem] = [
        NewsItem(imageName: "GeekMain", title: nil, description: nil)
        // Добавьте больше баннеров здесь, просто добавьте новые NewsItem
    ]
    
    // Даты для свайпа (сегодня, завтра, послезавтра)
    private var availableDays: [Date] {
        let calendar = Calendar.current
        return (0...2).compactMap { calendar.date(byAdding: .day, value: $0, to: Date()) }
    }
    
    // Локация для выбранного дня
    private var selectedDayCampus: String? {
        let daySchedule = getScheduleForOffset(selectedDayOffset)
        return daySchedule.lessons.first?.campus
    }
    
    // Тип недели определяется автоматически
    private var currentWeekType: WeekType {
        appSettings.currentWeekType
    }
    
    private var weekTypeText: String {
        currentWeekType.displayName
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Верхняя часть (не скроллится)
                VStack(spacing: 16) {
                    headerCard
                    
                    // Индикаторы дней (сегодня, завтра, послезавтра)
                    daySelector
                    
                    // Заголовок расписания + локация (статичный)
                    scheduleHeader
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .background(Color.black)
                
                // Свайпаемый контент дней (со внутренней прокруткой)
                TabView(selection: $selectedDayOffset) {
                    ForEach(0..<3, id: \.self) { offset in
                        ScrollView {
                            VStack(spacing: 16) {
                                dayContentScrollable(for: offset)
                                
                                // Рекламные баннеры внизу каждого дня
                                bannerSection
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(group.name)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                        Text("МПТ")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .onAppear {
                // Периодически обновляем замены
                Task {
                    await viewModel.loadReplacements(for: group)
                }
            }
        }
        .sheet(item: $selectedLessonForHomework) { lesson in
            let lessonId = selectedLessonType == .denominator ? lesson.denominatorId : lesson.id
            let lessonTitle = selectedLessonType == .denominator ? (lesson.titleDenominator ?? lesson.title) : lesson.title
            let lessonTeacher = selectedLessonType == .denominator ? (lesson.teacherDenominator ?? lesson.teacher) : lesson.teacher
            
            HomeworkEditorView(
                lesson: lesson,
                lessonTitle: lessonTitle,
                lessonTeacher: lessonTeacher,
                lessonId: lessonId,
                existing: homeworks[lessonId],
                onSave: { hw in
                    homeworks[lessonId] = hw
                    onHomeworksChanged?()
                }
            )
        }
    }

    // MARK: - Day Selector (Выбор дня)
    
    private var daySelector: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { offset in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDayOffset = offset
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(dayName(for: offset))
                            .font(.caption.weight(selectedDayOffset == offset ? .semibold : .medium))
                        
                        Text(dayDate(for: offset))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .foregroundColor(selectedDayOffset == offset ? .white : .white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selectedDayOffset == offset ? appSettings.currentWeekColor.opacity(0.3) : Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func dayName(for offset: Int) -> String {
        switch offset {
        case 0: return "Сегодня"
        case 1: return "Завтра"
        case 2: return "Послезавтра"
        default: return ""
        }
    }
    
    private func dayDate(for offset: Int) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
    
    // MARK: - Schedule Header (Статичный заголовок)
    
    private var scheduleHeader: some View {
        let daySchedule = getScheduleForOffset(selectedDayOffset)
        
        return HStack {
            Text("Расписание")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            if let campus = daySchedule.lessons.first?.campus {
                CampusBadge(campus: campus)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
    
    // MARK: - Day Content Scrollable (Контент дня для прокрутки)
    
    @ViewBuilder
    private func dayContentScrollable(for offset: Int) -> some View {
        let daySchedule = getScheduleForOffset(offset)
        let dayReplacements = getReplacementsForOffset(offset)
        
        VStack(spacing: 16) {
            // Пары
            if daySchedule.isDayOff || daySchedule.lessons.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow.opacity(0.6))
                    
                    Text(daySchedule.isDayOff ? "Выходной" : "Пар нет")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Отдыхайте!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(daySchedule.lessons.enumerated()), id: \.element.id) { index, lesson in
                        LessonCard(
                            lesson: lesson,
                            homework: homeworks[lesson.id],
                            homeworkDenominator: lesson.hasDenominator ? homeworks[lesson.denominatorId] : nil,
                            note: nil,
                            showLocation: false,
                            weekType: currentWeekType,
                            onTapNumerator: { 
                                selectedLessonForHomework = lesson
                                selectedLessonType = .numerator
                            },
                            onTapDenominator: lesson.hasDenominator ? {
                                selectedLessonForHomework = lesson
                                selectedLessonType = .denominator
                            } : nil,
                            onToggleComplete: { hw in
                                homeworks[hw.lessonId] = hw
                                onHomeworksChanged?()
                            },
                            onDelete: { hw in
                                homeworks.removeValue(forKey: hw.lessonId)
                                onHomeworksChanged?()
                            }
                        )
                        
                        // Перемена как разделитель
                        if index < daySchedule.lessons.count - 1,
                           let breakData = breakInfo(afterLesson: lesson.number) {
                            BreakDivider(
                                duration: breakData.duration,
                                startTime: breakData.start,
                                endTime: breakData.end
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                )
            }
            
            // Замены для этого дня
            if !dayReplacements.isEmpty {
                replacementsSectionFor(replacements: dayReplacements, dayOffset: offset)
            }
        }
    }
    
    // Получаем расписание для определённого дня (offset: 0 = сегодня, 1 = завтра, ...)
    private func getScheduleForOffset(_ offset: Int) -> DaySchedule {
        let calendar = Calendar.current
        guard let targetDate = calendar.date(byAdding: .day, value: offset, to: Date()) else {
            return schedule
        }
        return viewModel.getSchedule(for: targetDate, group: group)
    }
    
    // Получаем замены для определённого дня
    private func getReplacementsForOffset(_ offset: Int) -> [Replacement] {
        guard let replacements = viewModel.replacements else { return [] }
        
        let calendar = Calendar.current
        guard let targetDate = calendar.date(byAdding: .day, value: offset, to: Date()) else { return [] }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let targetDateString = formatter.string(from: targetDate)
        
        // Ищем замены на целевую дату
        for day in replacements.days {
            if day.date == targetDateString {
                return day.groups.flatMap { $0.replacements }
            }
        }
        
        return []
    }
    
    // Секция замен для конкретного дня
    @ViewBuilder
    private func replacementsSectionFor(replacements: [Replacement], dayOffset: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Заголовок
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(dayOffset == 0 ? "Изменения на сегодня" : "Изменения")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("\(replacements.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
            }
            .padding(.horizontal, 4)

            // Замены (в стиле расписания)
            VStack(spacing: 0) {
                ForEach(replacements) { replacement in
                    ReplacementRow(replacement: replacement)
                    
                    // Разделитель между заменами
                    if replacement.id != replacements.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.3))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.03))
                    )
            )
        }
        .padding(.top, 12)
    }
    
    private var headerCard: some View {
        // Цвет привязан к текущей неделе (автоматически)
        let isNumerator = currentWeekType == .numerator
        let colors: [Color] = isNumerator ? appSettings.numeratorGradient : appSettings.denominatorGradient

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        
        // Дата для отображения (зависит от выбранного дня)
        let calendar = Calendar.current
        let displayDate = calendar.date(byAdding: .day, value: selectedDayOffset, to: Date()) ?? Date()

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                Text(weekTypeText)
                    .font(appSettings.scaledFont(.subheadline).weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(dayName(for: selectedDayOffset))
                        .font(appSettings.scaledFont(.title).weight(.bold))
                    Text(formatter.string(from: displayDate).capitalized)
                        .font(appSettings.scaledFont(.subheadline))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .padding(20)
        }
        .frame(height: 160)
        .animation(.easeInOut(duration: 0.2), value: selectedDayOffset)
    }
    
    // MARK: - Banner Section (Рекламные баннеры)
    
    private var bannerSection: some View {
        VStack(spacing: 0) {
            if !banners.isEmpty {
                // Ненавязчивый заголовок (опционально, можно убрать)
                HStack {
                    Spacer()
                }
                .frame(height: 0)
                
                TabView(selection: $currentBannerIndex) {
                    ForEach(0..<banners.count, id: \.self) { index in
                        BannerCard(banner: banners[index])
                            .tag(index)
                            .padding(.horizontal, 4)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 130)
                .onReceive(Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()) { _ in
                    guard banners.count > 1 else { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        currentBannerIndex = (currentBannerIndex + 1) % banners.count
                    }
                }
                
                // Минималистичные индикаторы страниц
                if banners.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(0..<banners.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentBannerIndex ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                                .frame(width: index == currentBannerIndex ? 20 : 6, height: 4)
                                .animation(.spring(response: 0.3), value: currentBannerIndex)
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
        .padding(.top, 24)
    }
}

// MARK: - Banner Card

private struct BannerCard: View {
    let banner: NewsItem
    
    var body: some View {
        ZStack {
            // Пытаемся загрузить изображение из разных источников
            if let uiImage = loadBannerImage(named: banner.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 130)
                    .clipped()
            } else {
                // Fallback если изображение не найдено
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.04), Color.white.opacity(0.01)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 130)
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.25))
                            Text(banner.imageName)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    private func loadBannerImage(named: String) -> UIImage? {
        // Пробуем разные варианты загрузки
        if let image = UIImage(named: named) {
            return image
        }
        if let image = UIImage(named: "\(named).jpg") {
            return image
        }
        if let image = UIImage(named: "\(named).png") {
            return image
        }
        if let image = UIImage(named: "news/\(named)") {
            return image
        }
        if let image = UIImage(named: "news/\(named).jpg") {
            return image
        }
        if let image = UIImage(named: "news/\(named).png") {
            return image
        }
        // Пробуем загрузить из Bundle напрямую
        if let path = Bundle.main.path(forResource: named, ofType: nil, inDirectory: "news"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        return nil
    }
}

private struct CampusChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(isSelected ? 0.18 : 0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

// Цвета для числителя и знаменателя (теперь из настроек)
private var numeratorColor: Color { AppSettingsService.shared.numeratorColor }
private var denominatorColor: Color { AppSettingsService.shared.denominatorColor }

// Цвета для локаций
private let nakhimColor = Color.gray.opacity(0.6)  // Нейтральный для Нахимовского
private let nezhinColor = Color.gray.opacity(0.6)  // Нейтральный для Нежинской

// MARK: - Break Times (перемены)

/// Возвращает информацию о перемене между парами
private func breakInfo(afterLesson: Int) -> (duration: Int, start: String, end: String)? {
    switch afterLesson {
    case 1: return (10, "10:00", "10:10")   // После 1-й пары
    case 2: return (20, "11:40", "12:00")   // После 2-й пары (большая перемена)
    case 3: return (20, "13:30", "13:50")   // После 3-й пары (большая перемена)
    case 4: return (10, "15:20", "15:30")   // После 4-й пары
    case 5: return (5, "17:00", "17:05")    // После 5-й пары
    case 6: return (5, "18:35", "18:40")    // После 6-й пары
    default: return nil
    }
}

// MARK: - Week Type Badge

private struct WeekTypeBadge: View {
    let weekType: WeekType
    private var appSettings: AppSettingsService { AppSettingsService.shared }
    
    private var badgeColor: Color {
        weekType == .numerator ? appSettings.numeratorColor : appSettings.denominatorColor
    }
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(badgeColor)
                .frame(width: 4, height: 16)
            
            Text(weekType == .numerator ? "Числитель" : "Знаменатель")
                .font(appSettings.scaledFont(.subheadline).weight(.semibold))
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
    }
}

// MARK: - Lesson Card (компактный дизайн)

private struct LessonCard: View {
    let lesson: Lesson
    let homework: Homework?
    let homeworkDenominator: Homework?
    let note: DayNote?
    var showLocation: Bool = true
    var weekType: WeekType = .numerator
    var onTapNumerator: () -> Void
    var onTapDenominator: (() -> Void)? = nil
    var onToggleComplete: ((Homework) -> Void)? = nil
    var onDelete: ((Homework) -> Void)? = nil
    
    private var appSettings: AppSettingsService { AppSettingsService.shared }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Номер пары (компактнее)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 38 * appSettings.textScale, height: 38 * appSettings.textScale)

                Text("\(lesson.number)")
                    .font(appSettings.scaledFont(.callout).weight(.bold))
                    .foregroundColor(.white)
            }

            // Контент пары
            if lesson.hasDenominator {
                // Сдвоенная пара
                VStack(alignment: .leading, spacing: 0) {
                    Button(action: onTapNumerator) {
                        splitLessonRow(
                            title: lesson.title,
                            teacher: lesson.teacher,
                            color: numeratorColor,
                            isActive: weekType == .numerator,
                            homework: homework
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.vertical, 6)
                    
                    Button(action: { onTapDenominator?() }) {
                        splitLessonRow(
                            title: lesson.titleDenominator ?? "",
                            teacher: lesson.teacherDenominator ?? lesson.teacher,
                            color: denominatorColor,
                            isActive: weekType == .denominator,
                            homework: homeworkDenominator
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(lesson.startTime)
                        .font(appSettings.scaledFont(.footnote).weight(.medium))
                    Text(lesson.endTime)
                        .font(appSettings.scaledFont(.caption2))
                        .foregroundColor(.white.opacity(0.5))
                }
                .foregroundColor(.white)
            } else {
                // Обычная пара
                Button(action: onTapNumerator) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lesson.title)
                            .font(appSettings.scaledFont(.subheadline).weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Text(lesson.teacher)
                            .font(appSettings.scaledFont(.caption))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if let homework {
                            homeworkBadge(homework: homework)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(lesson.startTime)
                        .font(appSettings.scaledFont(.footnote).weight(.medium))
                    Text(lesson.endTime)
                        .font(appSettings.scaledFont(.caption2))
                        .foregroundColor(.white.opacity(0.5))
                }
                .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private func splitLessonRow(title: String, teacher: String, color: Color, isActive: Bool, homework: Homework?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6 * appSettings.textScale, height: 6 * appSettings.textScale)
                
                Text(title)
                    .font(appSettings.scaledFont(.caption).weight(.semibold))
                    .foregroundColor(isActive ? .white : .white.opacity(0.45))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            
            Text(teacher)
                .font(appSettings.scaledFont(.caption2))
                .foregroundColor(isActive ? .white.opacity(0.6) : .white.opacity(0.35))
                .padding(.leading, 12)
            
            if let homework {
                homeworkBadge(homework: homework)
                    .padding(.leading, 12)
            }
        }
    }
    
    @ViewBuilder
    private func homeworkBadge(homework: Homework) -> some View {
        HStack(spacing: 4) {
            Button(action: {
                var updated = homework
                updated.isCompleted.toggle()
                onToggleComplete?(updated)
            }) {
                Image(systemName: homework.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(homework.isCompleted ? .green : .white.opacity(0.4))
                    .font(appSettings.scaledFont(.caption2))
            }
            .buttonStyle(.plain)
            
            Text(homework.title)
                .font(appSettings.scaledFont(.caption2))
                .lineLimit(1)
            
            Spacer()
            
            if let onDelete {
                Button(action: { onDelete(homework) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.3))
                        .font(appSettings.scaledFont(.caption2))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundColor(homework.isCompleted ? .white.opacity(0.35) : .white.opacity(0.7))
        .strikethrough(homework.isCompleted)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.top, 2)
    }
}

// MARK: - Replacement Row (строка замены — как LessonCard)

private struct ReplacementRow: View {
    let replacement: Replacement
    
    // Проверка: это добавление (дополнительное занятие)?
    private var isAddition: Bool {
        replacement.originalSubject.lowercased().contains("дополнительное")
    }
    
    // Время пары
    private var lessonTime: (start: String, end: String) {
        switch replacement.pairNumber {
        case 1: return ("08:30", "10:00")
        case 2: return ("10:10", "11:40")
        case 3: return ("12:00", "13:30")
        case 4: return ("13:50", "15:20")
        case 5: return ("15:30", "17:00")
        case 6: return ("17:05", "18:35")
        case 7: return ("18:40", "20:10")
        default: return ("--:--", "--:--")
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Номер пары (как в LessonCard)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(replacement.isCancelled ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 38, height: 38)

                Text("\(replacement.pairNumber)")
                    .font(.callout.weight(.bold))
                    .foregroundColor(replacement.isCancelled ? .orange : .green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Если это добавление — показываем только новый предмет
                if isAddition {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .padding(.top, 3)
                        Text(replacement.newSubject)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if replacement.isCancelled {
                    // Отмена
                    VStack(alignment: .leading, spacing: 4) {
                        Text(replacement.originalSubject)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .strikethrough()
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .padding(.top, 3)
                            Text(replacement.newSubject)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    // Обычная замена
                    VStack(alignment: .leading, spacing: 4) {
                        Text(replacement.originalSubject)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .strikethrough()
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green.opacity(0.8))
                                .padding(.top, 3)
                            Text(replacement.newSubject)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Время справа
            VStack(alignment: .trailing, spacing: 1) {
                Text(lessonTime.start)
                    .font(.footnote.weight(.medium))
                Text(lessonTime.end)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Break Divider (перемена как разделитель)

private struct BreakDivider: View {
    let duration: Int
    let startTime: String
    let endTime: String
    private var appSettings: AppSettingsService { AppSettingsService.shared }
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .frame(maxWidth: 30)
            
            HStack(spacing: 6) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 9 * appSettings.textScale))
                Text("\(duration) мин")
                    .font(.system(size: 10 * appSettings.textScale, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.35))
            
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            Text("\(startTime) - \(endTime)")
                .font(.system(size: 9 * appSettings.textScale))
                .foregroundColor(.white.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// Для совместимости со старым кодом
private struct BreakCard: View {
    let duration: Int
    let startTime: String
    let endTime: String
    
    var body: some View {
        BreakDivider(duration: duration, startTime: startTime, endTime: endTime)
    }
}

// MARK: - Campus Badge (бейдж локации — серый)

private struct CampusBadge: View {
    let campus: String
    
    var body: some View {
        Text(campus)
            .font(.caption2.weight(.medium))
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
            )
    }
}

private struct ReplacementCard: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(lesson.number) пара")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text("\(lesson.startTime) – \(lesson.endTime)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(lesson.title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            Text(lesson.teacher)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))

            if let original = lesson.originalTitle {
                Text(original)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .strikethrough(true, color: .white.opacity(0.4))
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Week, Bells, Settings

struct WeekView: View {
    let group: Group
    @ObservedObject var viewModel: ScheduleViewModel
    @ObservedObject var appSettings = AppSettingsService.shared
    @Binding var homeworks: [UUID: Homework]
    var onHomeworksChanged: (() -> Void)? = nil
    
    @State private var selectedDate: Date = Date()
    @State private var currentWeekStart: Date
    @State private var dayNotes: [Date: DayNote] = [:]
    @State private var selectedLessonForHomework: Lesson?
    @State private var selectedLessonType: LessonType = .numerator
    @State private var showingWeekSchedule: Bool = true  // true = показываем неделю, false = показываем день
    @State private var isCalendarExpanded: Bool = false  // развернут ли календарь на месяц
    
    init(group: Group, viewModel: ScheduleViewModel, homeworks: Binding<[UUID: Homework]>, onHomeworksChanged: (() -> Void)? = nil) {
        self.group = group
        self.viewModel = viewModel
        self._homeworks = homeworks
        self.onHomeworksChanged = onHomeworksChanged
        let calendar = Calendar.current
        let today = Date()
        // Находим понедельник текущей недели
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7  // Понедельник = 0
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        _currentWeekStart = State(initialValue: weekStart)
    }
    
    private var selectedDaySchedule: DaySchedule {
        return viewModel.getSchedule(for: selectedDate, group: group)
    }
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        // Все 7 дней недели (пн-вс)
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: currentWeekStart)
        }
    }
    
    private var weekSchedules: [DaySchedule] {
        weekDays.map { date in
            viewModel.getSchedule(for: date, group: group)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Календарь
                        CalendarWeekView(
                            weekStart: currentWeekStart,
                            selectedDate: $selectedDate,
                            dayNotes: dayNotes,
                            isExpanded: $isCalendarExpanded,
                            onWeekChange: { newWeekStart in
                                withAnimation(.spring()) {
                                    currentWeekStart = newWeekStart
                                }
                            },
                            onDaySelect: { date in
                                withAnimation(.spring()) {
                                    selectedDate = date
                                    // Обновляем неделю, чтобы показать неделю с выбранным днём
                                    let calendar = Calendar.current
                                    let weekday = calendar.component(.weekday, from: date)
                                    let daysFromMonday = (weekday + 5) % 7  // Понедельник = 0
                                    currentWeekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
                                    // Переключаемся на просмотр дня
                                    showingWeekSchedule = false
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        if showingWeekSchedule {
                            // Расписание всей недели
                            VStack(alignment: .leading, spacing: 0) {
                                // Заголовок с типом недели
                                HStack(alignment: .center) {
                                    Text("Расписание недели")
                                        .font(appSettings.scaledFont(.title2).weight(.bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // Индикатор типа недели (автоматически определяется)
                                    WeekTypeBadge(weekType: appSettings.currentWeekType)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                                
                                ForEach(Array(weekSchedules.enumerated()), id: \.element.id) { index, daySchedule in
                                    let calendar = Calendar.current
                                    let weekday = calendar.component(.weekday, from: daySchedule.date)
                                    let isSunday = weekday == 1
                                    
                                    if isSunday {
                                        // Воскресенье - выходной
                                        SundayCard(date: daySchedule.date)
                                            .padding(.horizontal, 20)
                                    } else {
                                        WeekDaySection(
                                            day: daySchedule,
                                            dayNotes: dayNotes,
                                            homeworks: homeworks,
                                            weekType: appSettings.currentWeekType,
                                            onLessonTapNumerator: { lesson in
                                                selectedLessonForHomework = lesson
                                                selectedLessonType = .numerator
                                            },
                                            onLessonTapDenominator: { lesson in
                                                selectedLessonForHomework = lesson
                                                selectedLessonType = .denominator
                                            },
                                            onToggleComplete: { hw in
                                                homeworks[hw.lessonId] = hw
                                                onHomeworksChanged?()
                                            },
                                            onDelete: { hw in
                                                homeworks.removeValue(forKey: hw.lessonId)
                                                onHomeworksChanged?()
                                            }
                                        )
                                    }
                                    
                                    // Элегантный разделитель между днями (кроме последнего)
                                    if index < weekSchedules.count - 1 {
                                        HStack {
                                            Spacer()
                                            RoundedRectangle(cornerRadius: 1)
                                                .fill(Color.white.opacity(0.15))
                                                .frame(height: 1)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 40)
                                        .padding(.vertical, 20)
                                    }
                                }
                            }
                        } else {
                            // Расписание выбранного дня
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            showingWeekSchedule = true
                                            // Возвращаем подсветку на сегодняшний день
                                            selectedDate = Date()
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.left")
                                            Text("Вернуться к неделе")
                                        }
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.1))
                                        )
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                let calendar = Calendar.current
                                let weekday = calendar.component(.weekday, from: selectedDate)
                                let isSunday = weekday == 1
                                
                                if isSunday {
                                    // Воскресенье - выходной
                                    VStack(spacing: 16) {
                                        Text(selectedDayFormatted)
                                            .font(.title2.weight(.bold))
                                            .foregroundColor(.white)
                                        
                                        SundayCard(date: selectedDate)
                                    }
                                    .padding(.horizontal, 20)
                                } else {
                                    // Заголовок дня с локацией
                                    HStack {
                                        Text(selectedDayFormatted)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                        Spacer()
                                        if let campus = selectedDaySchedule.lessons.first?.campus, !campus.isEmpty {
                                            CampusBadge(campus: campus)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    
                                    if selectedDaySchedule.lessons.isEmpty {
                                        Text("На этот день пар нет")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.5))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 24)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .fill(.ultraThinMaterial.opacity(0.3))
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                            .fill(Color.white.opacity(0.03))
                                                    )
                                            )
                                            .padding(.horizontal, 12)
                                    } else {
                                        VStack(spacing: 0) {
                                            ForEach(Array(selectedDaySchedule.lessons.enumerated()), id: \.element.id) { index, lesson in
                                                LessonCard(
                                                    lesson: lesson,
                                                    homework: homeworks[lesson.id],
                                                    homeworkDenominator: lesson.hasDenominator ? homeworks[lesson.denominatorId] : nil,
                                                    note: nil,
                                                    showLocation: false,
                                                    weekType: appSettings.currentWeekType,
                                                    onTapNumerator: {
                                                        selectedLessonForHomework = lesson
                                                        selectedLessonType = .numerator
                                                    },
                                                    onTapDenominator: lesson.hasDenominator ? {
                                                        selectedLessonForHomework = lesson
                                                        selectedLessonType = .denominator
                                                    } : nil,
                                                    onToggleComplete: { hw in
                                                        homeworks[hw.lessonId] = hw
                                                        onHomeworksChanged?()
                                                    },
                                                    onDelete: { hw in
                                                        homeworks.removeValue(forKey: hw.lessonId)
                                                        onHomeworksChanged?()
                                                    }
                                                )
                                                
                                                if index < selectedDaySchedule.lessons.count - 1,
                                                   let breakData = breakInfo(afterLesson: lesson.number) {
                                                    BreakDivider(
                                                        duration: breakData.duration,
                                                        startTime: breakData.start,
                                                        endTime: breakData.end
                                                    )
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .fill(.ultraThinMaterial.opacity(0.3))
                                                .background(
                                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                        .fill(Color.white.opacity(0.03))
                                                )
                                        )
                                        .padding(.horizontal, 12)
                                    }
                                    
                                    if !selectedDaySchedule.replacements.isEmpty {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Изменения")
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(.white.opacity(0.6))
                                            ForEach(selectedDaySchedule.replacements) { lesson in
                                                ReplacementCard(lesson: lesson)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Неделя")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedLessonForHomework) { lesson in
            let lessonId = selectedLessonType == .denominator ? lesson.denominatorId : lesson.id
            let lessonTitle = selectedLessonType == .denominator ? (lesson.titleDenominator ?? lesson.title) : lesson.title
            let lessonTeacher = selectedLessonType == .denominator ? (lesson.teacherDenominator ?? lesson.teacher) : lesson.teacher
            
            HomeworkEditorView(
                lesson: lesson,
                lessonTitle: lessonTitle,
                lessonTeacher: lessonTeacher,
                lessonId: lessonId,
                existing: homeworks[lessonId],
                onSave: { hw in
                    homeworks[lessonId] = hw
                    onHomeworksChanged?()
                }
            )
        }
    }
    
    private var selectedDayFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: selectedDate).capitalized
    }
}

// MARK: - Calendar Components

private struct CalendarWeekView: View {
    let weekStart: Date
    @Binding var selectedDate: Date
    let dayNotes: [Date: DayNote]
    @Binding var isExpanded: Bool
    let onWeekChange: (Date) -> Void
    let onDaySelect: (Date) -> Void
    
    @State private var currentMonthStart: Date
    
    init(weekStart: Date, selectedDate: Binding<Date>, dayNotes: [Date: DayNote], isExpanded: Binding<Bool>, onWeekChange: @escaping (Date) -> Void, onDaySelect: @escaping (Date) -> Void) {
        self.weekStart = weekStart
        self._selectedDate = selectedDate
        self.dayNotes = dayNotes
        self._isExpanded = isExpanded
        self.onWeekChange = onWeekChange
        self.onDaySelect = onDaySelect
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: weekStart)
        _currentMonthStart = State(initialValue: calendar.date(from: components) ?? weekStart)
    }
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        // Все 7 дней недели (пн-вс)
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }
    
    private var monthDays: [Date?] {
        let calendar = Calendar.current
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthStart))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDay)!.count
        let adjustedFirstWeekday = (firstWeekday + 5) % 7  // Понедельник = 0
        
        var days: [Date?] = []
        // Пустые дни до начала месяца
        for _ in 0..<adjustedFirstWeekday {
            days.append(nil)
        }
        // Дни месяца
        for day in 1...daysInMonth {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        return days
    }
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonthStart).capitalized
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Заголовок с навигацией
            HStack {
                Button(action: {
                    if isExpanded {
                        let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
                        withAnimation(.spring()) {
                            currentMonthStart = prevMonth
                        }
                    } else {
                        let prevWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? weekStart
                        onWeekChange(prevWeek)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                
                Spacer()
                
                Text(monthYearText)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    if isExpanded {
                        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
                        withAnimation(.spring()) {
                            currentMonthStart = nextMonth
                        }
                    } else {
                        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? weekStart
                        onWeekChange(nextWeek)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            
            if isExpanded {
                // Полный календарь месяца
                VStack(spacing: 12) {
                    // Заголовки дней недели
                    HStack(spacing: 0) {
                        ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { dayName in
                            Text(dayName)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Дни месяца (7 колонок)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                        ForEach(Array(monthDays.enumerated()), id: \.offset) { index, date in
                            if let date = date {
                                CalendarDayView(
                                    date: date,
                                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                    hasNote: dayNotes[date] != nil,
                                    onTap: {
                                        withAnimation(.spring()) {
                                            selectedDate = date
                                            isExpanded = false
                                            onDaySelect(date)
                                        }
                                    }
                                )
                            } else {
                                Color.clear
                                    .frame(height: 44)
                            }
                        }
                    }
                }
            } else {
                // Дни недели
                HStack(spacing: 8) {
                    ForEach(weekDays, id: \.self) { date in
                        CalendarDayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            hasNote: dayNotes[date] != nil,
                            onTap: {
                                onDaySelect(date)
                            }
                        )
                    }
                }
            }
            
            // Кнопка разворачивания/сворачивания
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                    if isExpanded {
                        // Обновляем месяц при разворачивании
                        let calendar = Calendar.current
                        let components = calendar.dateComponents([.year, .month], from: weekStart)
                        currentMonthStart = calendar.date(from: components) ?? weekStart
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Text(isExpanded ? "Свернуть" : "Развернуть месяц")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let hasNote: Bool
    let onTap: () -> Void
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).capitalized
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isSunday: Bool {
        let calendar = Calendar.current
        return calendar.component(.weekday, from: date) == 1
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(dayName)
                    .font(.caption.weight(.medium))
                    .foregroundColor(isSunday ? .white.opacity(0.5) : .white.opacity(0.7))
                
                Text(dayNumber)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(isSelected ? .black : (isSunday ? .white.opacity(0.5) : .white))
                
                // Индикатор заметки
                if hasNote {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isSelected ? Color.black.opacity(0.3) : Color.white.opacity(0.6))
                        .frame(width: 24, height: 3)
                } else {
                    Spacer()
                        .frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.white : (isToday ? Color.white.opacity(0.1) : (isSunday ? Color.white.opacity(0.03) : Color.clear)))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Note Components

private struct NoteCard: View {
    let note: DayNote
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "note.text")
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 20)
            
            Text(note.text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

struct DayNoteEditorView: View {
    let date: Date
    let existingNote: DayNote?
    let onSave: (DayNote) -> Void
    let onCancel: () -> Void
    
    @State private var noteText: String
    @FocusState private var isFocused: Bool
    
    init(date: Date, existingNote: DayNote?, onSave: @escaping (DayNote) -> Void, onCancel: @escaping () -> Void) {
        self.date = date
        self.existingNote = existingNote
        self.onSave = onSave
        self.onCancel = onCancel
        _noteText = State(initialValue: existingNote?.text ?? "")
    }
    
    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date).capitalized
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 20) {
                    Text(dateFormatted)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    TextEditor(text: $noteText)
                        .focused($isFocused)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .padding(.horizontal, 20)
                        .frame(minHeight: 200)
                    
                    Spacer()
                }
            }
            .navigationTitle("Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        var note = existingNote ?? DayNote(date: date, text: noteText)
                        note.text = noteText
                        onSave(note)
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isFocused = true
        }
    }
}

private struct SundayCard: View {
    let date: Date
    private var appSettings: AppSettingsService { AppSettingsService.shared }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date).capitalized
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate)
                        .font(appSettings.scaledFont(.headline).weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            
            VStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 48 * appSettings.textScale))
                    .foregroundColor(.white.opacity(0.4))
                
                Text("Выходной")
                    .font(appSettings.scaledFont(.title3).weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Отдыхай и набирайся сил")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}

private struct WeekDaySection: View {
    let day: DaySchedule
    let dayNotes: [Date: DayNote]
    let homeworks: [UUID: Homework]
    let weekType: WeekType
    let onLessonTapNumerator: (Lesson) -> Void
    var onLessonTapDenominator: ((Lesson) -> Void)? = nil
    var onToggleComplete: ((Homework) -> Void)? = nil
    var onDelete: ((Homework) -> Void)? = nil
    
    private var appSettings: AppSettingsService { AppSettingsService.shared }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: day.date).capitalized
    }
    
    // Локация дня берётся из первой пары
    private var dayCampus: String? {
        day.lessons.first?.campus
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок дня с локацией справа
            HStack {
                Text(formattedDate)
                    .font(appSettings.scaledFont(.subheadline).weight(.semibold))
                    .foregroundColor(.white)
                
                if dayNotes[day.date] != nil {
                    Image(systemName: "note.text")
                        .font(appSettings.scaledFont(.caption2))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Локация с цветной подсветкой
                if let campus = dayCampus, !campus.isEmpty {
                    CampusBadge(campus: campus)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Все пары дня в стеклянном контейнере
            if day.lessons.isEmpty {
                Text("Пар нет")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(day.lessons.enumerated()), id: \.element.id) { index, lesson in
                        LessonCard(
                            lesson: lesson,
                            homework: homeworks[lesson.id],
                            homeworkDenominator: lesson.hasDenominator ? homeworks[lesson.denominatorId] : nil,
                            note: nil,
                            showLocation: false,
                            weekType: weekType,
                            onTapNumerator: {
                                onLessonTapNumerator(lesson)
                            },
                            onTapDenominator: lesson.hasDenominator ? {
                                onLessonTapDenominator?(lesson)
                            } : nil,
                            onToggleComplete: { hw in
                                onToggleComplete?(hw)
                            },
                            onDelete: { hw in
                                onDelete?(hw)
                            }
                        )
                        
                        // Перемена как разделитель
                        if index < day.lessons.count - 1,
                           let breakData = breakInfo(afterLesson: lesson.number) {
                            BreakDivider(
                                duration: breakData.duration,
                                startTime: breakData.start,
                                endTime: breakData.end
                            )
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.3))
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                )
                .padding(.horizontal, 12)
            }
            
            // Замены
            if !day.replacements.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Изменения")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    ForEach(day.replacements) { lesson in
                        ReplacementCard(lesson: lesson)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.bottom, 12)
    }
}

struct BellsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Звонки техникума")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)

                        Text("Расписание звонков на учебный день")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        VStack(spacing: 16) {
                            ForEach(MockData.bells, id: \.pair) { item in
                                BellRow(pair: item.pair, time: item.time, breakDescription: item.breakDescription)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Звонки")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }
}

private struct BellRow: View {
    let pair: Int
    let time: String
    let breakDescription: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)

                Text("\(pair)")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(time)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                Text(breakDescription)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

struct SettingsView: View {
    let selectedSpecialty: Specialty
    let selectedGroup: Group
    
    @ObservedObject var viewModel: ScheduleViewModel
    @ObservedObject var appSettings = AppSettingsService.shared
    @Environment(\.openURL) private var openURL
    var onChangeGroup: (Specialty, Group) -> Void
    
    @State private var showingSpecialtyPicker = false
    @State private var showingGroupPicker = false
    @State private var tempSelectedSpecialty: Specialty?
    @State private var tempSelectedGroup: Group?
    @State private var toastMessage: String? = nil
    @State private var showToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        GroupBoxView(
                            title: "Учебная группа",
                            content: {
                                // Специальность - нажимаем чтобы изменить
                                Button(action: {
                                    tempSelectedSpecialty = selectedSpecialty
                                    showingSpecialtyPicker = true
                                }) {
                                    SettingsRow(
                                        icon: "book.closed.fill",
                                        title: "Специальность",
                                        subtitle: selectedSpecialty.name
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                // Группа - нажимаем чтобы изменить
                                Button(action: {
                                    tempSelectedGroup = selectedGroup
                                    showingGroupPicker = true
                                }) {
                                    SettingsRow(
                                        icon: "graduationcap.fill",
                                        title: "Группа",
                                        subtitle: selectedGroup.name
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        )

                        // MARK: - Размер текста
                        GroupBoxView(
                            title: "Размер текста",
                            content: {
                                VStack(spacing: 16) {
                                    HStack {
                                        Image(systemName: "textformat.size.smaller")
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        Slider(value: $appSettings.textScale, in: 0.8...1.4, step: 0.1)
                                            .tint(.white)
                                        
                                        Image(systemName: "textformat.size.larger")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    
                                    // Превью размера
                                    HStack {
                                        Text("Математика")
                                            .font(appSettings.scaledFont(.headline))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(appSettings.textScale * 100))%")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.5))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.white.opacity(0.1)))
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        )
                        
                        // MARK: - Цвета недель
                        GroupBoxView(
                            title: "Цвета недель",
                            content: {
                                VStack(spacing: 20) {
                                    // Числитель
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Circle()
                                                .fill(appSettings.numeratorColor)
                                                .frame(width: 12, height: 12)
                                            Text("Числитель")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 10) {
                                                ForEach(Array(AppSettingsService.colorPresets.enumerated()), id: \.offset) { index, preset in
                                                    ColorPresetButton(
                                                        color: preset.color,
                                                        isSelected: appSettings.numeratorColorIndex == index,
                                                        action: { 
                                                            appSettings.setColor(index, for: .numerator)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    // Знаменатель
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Circle()
                                                .fill(appSettings.denominatorColor)
                                                .frame(width: 12, height: 12)
                                            Text("Знаменатель")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundColor(.white)
                                        }
                                        
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 10) {
                                                ForEach(Array(AppSettingsService.colorPresets.enumerated()), id: \.offset) { index, preset in
                                                    ColorPresetButton(
                                                        color: preset.color,
                                                        isSelected: appSettings.denominatorColorIndex == index,
                                                        action: { 
                                                            appSettings.setColor(index, for: .denominator)
                                                        }
                                                    )
                                                }
                                            }
                                        }
                                    }
                                    
                                    // Превью градиента
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                LinearGradient(
                                                    colors: appSettings.numeratorGradient,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(height: 50)
                                            .overlay(
                                                Text("Числитель")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(.white)
                                            )
                                        
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                LinearGradient(
                                                    colors: appSettings.denominatorGradient,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(height: 50)
                                            .overlay(
                                                Text("Знаменатель")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        )
                        
                        // MARK: - Сброс настроек
                        GroupBoxView(
                            title: "Сброс",
                            content: {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        appSettings.resetToDefaults()
                                        showToastMessage("Настройки сброшены")
                                    }
                                }) {
                                    SettingsRow(
                                        icon: "arrow.counterclockwise",
                                        title: "Сбросить настройки",
                                        subtitle: "Вернуть размер и цвета по умолчанию"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        )

                        GroupBoxView(
                            title: "Расписание",
                            content: {
                                Button(action: {
                                    Task {
                                        await viewModel.loadSchedule(for: selectedGroup)
                                        showToastMessage("Расписание обновлено")
                                    }
                                }) {
                                    SettingsRow(
                                        icon: "arrow.clockwise",
                                        title: "Обновить расписание",
                                        subtitle: viewModel.isLoading ? "Загрузка..." : "Загрузить актуальное расписание"
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isLoading)
                            }
                        )
                        
                        // MARK: - Очистка кеша
                        GroupBoxView(
                            title: "Кеш",
                            content: {
                                VStack(spacing: 12) {
                                    Button(action: {
                                        StorageService.shared.clearScheduleCache()
                                        showToastMessage("Кеш расписания очищен")
                                    }) {
                                        SettingsRow(
                                            icon: "trash.fill",
                                            title: "Очистить кеш расписания",
                                            subtitle: "Удалить сохранённое расписание (ДЗ сохранятся)"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    Button(action: {
                                        StorageService.shared.clearContentCache()
                                        showToastMessage("Кеш контента очищен")
                                    }) {
                                        SettingsRow(
                                            icon: "photo.fill",
                                            title: "Очистить кеш контента",
                                            subtitle: "Удалить кеш новостей и рекомендаций"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                    
                                    Button(action: {
                                        StorageService.shared.clearCache()
                                        showToastMessage("Весь кеш очищен")
                                    }) {
                                        SettingsRow(
                                            icon: "trash.circle.fill",
                                            title: "Очистить весь кеш",
                                            subtitle: "Удалить весь кеш (ДЗ и настройки сохранятся)"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        )

                        GroupBoxView(
                            title: "Обратная связь",
                            content: {
                                Button(action: {
                                    // Открываем Telegram разработчика
                                    if let url = URL(string: "https://t.me/papajonsez") {
                                        openURL(url)
                                    }
                                }) {
                                    SettingsRow(
                                        icon: "paperplane.fill",
                                        title: "Связаться с разработчиком",
                                        subtitle: "@papajonsez в Telegram"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        )
                        
                        // Показываем ошибку если есть
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                
                // Toast уведомление сверху
                if showToast, let message = toastMessage {
                    VStack {
                        ToastView(message: message)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, 60)
                        Spacer()
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showToast)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSpecialtyPicker) {
            SpecialtyPickerSheet(
                viewModel: viewModel,
                selectedSpecialty: $tempSelectedSpecialty,
                onSelect: { specialty in
                    showingSpecialtyPicker = false
                    // После выбора специальности показываем выбор группы
                    Task {
                        await viewModel.loadGroups(for: specialty)
                        tempSelectedSpecialty = specialty
                        showingGroupPicker = true
                    }
                }
            )
        }
        .sheet(isPresented: $showingGroupPicker) {
            GroupPickerSheet(
                viewModel: viewModel,
                specialty: tempSelectedSpecialty ?? selectedSpecialty,
                selectedGroup: $tempSelectedGroup,
                onSelect: { group in
                    showingGroupPicker = false
                    // Сохраняем выбор и перезагружаем расписание
                    let specialty = tempSelectedSpecialty ?? selectedSpecialty
                    onChangeGroup(specialty, group)
                }
            )
        }
        .task {
            // Загружаем специальности для выбора
            if viewModel.specialties.isEmpty {
                await viewModel.loadSpecialties()
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Настройки")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            Text("Персонализируйте расписание и связь с техникумом")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    // Показать toast-уведомление
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        
        // Скрыть через 2 секунды
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

// MARK: - Toast View (Уведомление сверху)

private struct ToastView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
            
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.9))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Specialty Picker Sheet

private struct SpecialtyPickerSheet: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var selectedSpecialty: Specialty?
    var onSelect: (Specialty) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.specialties) { specialty in
                                Button(action: {
                                    onSelect(specialty)
                                }) {
                                    HStack {
                                        Text(specialty.name)
                                            .font(.body)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if selectedSpecialty?.id == specialty.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(selectedSpecialty?.id == specialty.id ? 0.12 : 0.06))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Выберите специальность")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if viewModel.specialties.isEmpty {
                await viewModel.loadSpecialties()
            }
        }
    }
}

// MARK: - Group Picker Sheet

private struct GroupPickerSheet: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let specialty: Specialty
    @Binding var selectedGroup: Group?
    var onSelect: (Group) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else if viewModel.groups.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Группы не найдены")
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.groups) { group in
                                Button(action: {
                                    onSelect(group)
                                }) {
                                    HStack {
                                        Text(group.name)
                                            .font(.body)
                                            .foregroundColor(.white)
                                        Spacer()
                                        if selectedGroup?.id == group.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(selectedGroup?.id == group.id ? 0.12 : 0.06))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("Выберите группу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadGroups(for: specialty)
        }
    }
}

private struct GroupBoxView<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)

            VStack(spacing: 8) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Color Preset Button

private struct ColorPresetButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 3)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}



