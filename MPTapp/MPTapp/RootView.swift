import SwiftUI

struct RootView: View {
    @AppStorage("selectedSpecialtyId") private var selectedSpecialtyId: String?
    @AppStorage("selectedGroupId") private var selectedGroupId: String?
    @AppStorage("selectedSpecialtyName") private var selectedSpecialtyName: String?
    @AppStorage("selectedGroupName") private var selectedGroupName: String?

    var body: some View {
        if let specialtyId = selectedSpecialtyId,
           let groupId = selectedGroupId,
           let specialtyName = selectedSpecialtyName,
           let groupName = selectedGroupName {
            // Создаём объекты из сохранённых данных
            let specialty = Specialty(id: specialtyId, name: specialtyName)
            let group = Group(id: groupId, name: groupName, specialtyId: specialtyId)
            MainTabView(
                selectedSpecialty: specialty,
                selectedGroup: group,
                onChangeGroup: { newSpecialty, newGroup in
                    // Сохраняем новый выбор
                    selectedSpecialtyId = newSpecialty.id
                    selectedSpecialtyName = newSpecialty.name
                    selectedGroupId = newGroup.id
                    selectedGroupName = newGroup.name
                }
            )
        } else {
            OnboardingFlowView()
        }
    }
}

struct MainTabView: View {
    @State private var selectedSpecialty: Specialty
    @State private var selectedGroup: Group
    var onChangeGroup: (Specialty, Group) -> Void

    @StateObject private var viewModel = ScheduleViewModel()
    @State private var todaySchedule: DaySchedule
    @State private var homeworks: [UUID: Homework] = [:] // lessonId -> homework

    init(selectedSpecialty: Specialty, selectedGroup: Group, onChangeGroup: @escaping (Specialty, Group) -> Void) {
        _selectedSpecialty = State(initialValue: selectedSpecialty)
        _selectedGroup = State(initialValue: selectedGroup)
        self.onChangeGroup = onChangeGroup
        
        // Загружаем сохраненное расписание из кеша сразу при запуске
        // Это важно для быстрого отображения без ожидания сервера
        let cachedSchedules = StorageService.shared.loadSchedule(for: selectedGroup.id) ?? []
        let cachedWeekInfo = StorageService.shared.loadWeekInfo()
        
        // Пытаемся найти расписание на сегодня
        let today = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: today)
        let dayIndex = weekday == 1 ? nil : (weekday + 5) % 7 // пн=0, вт=1, ..., сб=5
        
        let initialSchedule: DaySchedule
        if let dayIdx = dayIndex,
           let templateSchedule = cachedSchedules.first(where: { schedule in
               let templateWeekday = calendar.component(.weekday, from: schedule.date)
               let templateDayIndex = (templateWeekday + 5) % 7
               return templateDayIndex == dayIdx
           }) {
            // Есть сохраненное расписание для сегодня
            initialSchedule = DaySchedule(
                date: today,
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
                        date: today,
                        titleDenominator: lesson.titleDenominator,
                        teacherDenominator: lesson.teacherDenominator
                    )
                },
                replacements: [],
                isDayOff: templateSchedule.isDayOff
            )
        } else {
            // Нет сохраненного расписания - используем пустое
            initialSchedule = DaySchedule(date: today, lessons: [], replacements: [], isDayOff: weekday == 1)
        }
        
        _todaySchedule = State(initialValue: initialSchedule)
        // Загружаем ДЗ из кеша
        _homeworks = State(initialValue: StorageService.shared.loadHomeworks())
    }

    var body: some View {
        TabView {
            TodayView(
                group: selectedGroup,
                schedule: $todaySchedule,
                homeworks: $homeworks,
                viewModel: viewModel,
                onHomeworksChanged: {
                    // Сохраняем ДЗ при изменении
                    StorageService.shared.saveHomeworks(homeworks)
                }
            )
            .tabItem {
                Image(systemName: "bolt.fill")
                Text("Сегодня")
            }

            WeekView(
                group: selectedGroup,
                viewModel: viewModel,
                homeworks: $homeworks,
                onHomeworksChanged: {
                    // Сохраняем ДЗ при изменении
                    StorageService.shared.saveHomeworks(homeworks)
                }
            )
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Неделя")
                }

            BellsView()
                .tabItem {
                    Image(systemName: "bell")
                    Text("Звонки")
                }

            SettingsView(
                selectedSpecialty: selectedSpecialty,
                selectedGroup: selectedGroup,
                viewModel: viewModel,
                onChangeGroup: { newSpecialty, newGroup in
                    // Обновляем локальное состояние
                    selectedSpecialty = newSpecialty
                    selectedGroup = newGroup
                    // Сохраняем в AppStorage
                    onChangeGroup(newSpecialty, newGroup)
                    // Перезагружаем расписание и замены
                    Task {
                        await viewModel.loadSchedule(for: newGroup)
                        await viewModel.loadReplacements(for: newGroup)
                        todaySchedule = viewModel.getTodaySchedule(for: newGroup)
                    }
                }
            )
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Настройки")
                }
        }
        .tint(.white)
        .preferredColorScheme(.dark)
        .task {
            // Сначала загружаем из кеша (мгновенно) - это уже должно быть загружено в viewModel.loadSchedule
            // но на всякий случай убеждаемся что данные из кеша используются
            if let cachedWeekInfo = StorageService.shared.loadWeekInfo() {
                viewModel.weekInfo = cachedWeekInfo
            }
            if let cachedSchedules = StorageService.shared.loadSchedule(for: selectedGroup.id) {
                viewModel.weekSchedules = cachedSchedules
                // Обновляем todaySchedule из кеша сразу
                todaySchedule = viewModel.getTodaySchedule(for: selectedGroup)
            }
            
            // Теперь обновляем с сервера в фоне (если сервер доступен)
            // Это делаем асинхронно, не блокируя отображение
            Task {
                // Загружаем актуальные данные с сервера
                await viewModel.loadWeekInfo()
                await viewModel.loadSchedule(for: selectedGroup)
                // Обновляем отображаемое расписание после загрузки
                await MainActor.run {
                    todaySchedule = viewModel.getTodaySchedule(for: selectedGroup)
                }
            }
            
            // Замены загружаем отдельно (они менее критичны)
            Task {
                await viewModel.loadReplacements(for: selectedGroup)
            }
            
            // Извлекаем преподавателей и создаём рейтинги
            viewModel.extractAndCreateTeacherRatings()
        }
    }
}
