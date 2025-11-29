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
        _todaySchedule = State(initialValue: MockData.todaySchedule(for: selectedGroup, date: Date()))
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

            NewsView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("Новости")
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
            await viewModel.loadWeekInfo()
            await viewModel.loadSchedule(for: selectedGroup)
            await viewModel.loadReplacements(for: selectedGroup)
            // Извлекаем преподавателей и создаём рейтинги
            viewModel.extractAndCreateTeacherRatings()
            // Обновляем todaySchedule из загруженных данных
            todaySchedule = viewModel.getTodaySchedule(for: selectedGroup)
        }
    }
}
