import SwiftUI

struct HomeworkEditorView: View {
    let lesson: Lesson
    let lessonTitle: String      // Название предмета (может быть числитель или знаменатель)
    let lessonTeacher: String    // ФИО преподавателя (может быть числитель или знаменатель)
    let lessonId: UUID           // ID для сохранения ДЗ
    let existing: Homework?

    var onSave: (Homework) -> Void
    var onDayNoteCreated: ((Date, String) -> Void)? = nil  // Callback для создания заметки в календаре

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var shouldRemind: Bool = false

    // Основной инициализатор с отдельным lessonTitle, lessonTeacher и lessonId
    init(lesson: Lesson, lessonTitle: String, lessonTeacher: String, lessonId: UUID, existing: Homework?, onSave: @escaping (Homework) -> Void, onDayNoteCreated: ((Date, String) -> Void)? = nil) {
        self.lesson = lesson
        self.lessonTitle = lessonTitle
        self.lessonTeacher = lessonTeacher
        self.lessonId = lessonId
        self.existing = existing
        self.onSave = onSave
        self.onDayNoteCreated = onDayNoteCreated

        _title = State(initialValue: existing?.title ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _dueDate = State(initialValue: existing?.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        _shouldRemind = State(initialValue: existing?.shouldRemind ?? false)
    }

    // Удобный инициализатор для обычных пар
    init(lesson: Lesson, existing: Homework?, onSave: @escaping (Homework) -> Void, onDayNoteCreated: ((Date, String) -> Void)? = nil) {
        self.init(lesson: lesson, lessonTitle: lesson.title, lessonTeacher: lesson.teacher, lessonId: lesson.id, existing: existing, onSave: onSave, onDayNoteCreated: onDayNoteCreated)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Предмет")) {
                    Text(lessonTitle)
                        .font(.subheadline)
                    Text(lessonTeacher)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Домашнее задание")) {
                    TextField("Краткое задание", text: $title)
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section(header: Text("Срок и напоминание")) {
                    DatePicker("Сдать до", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    Toggle("Напомнить", isOn: $shouldRemind)
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    Text("Уведомления пока не настроены, но вы уже можете планировать дедлайны.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Домашнее задание")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let hw = Homework(
                            id: existing?.id ?? UUID(),
                            lessonId: lessonId,  // Используем переданный lessonId
                            title: title.isEmpty ? "Домашнее задание" : title,
                            notes: notes,
                            dueDate: dueDate,
                            shouldRemind: shouldRemind,
                            isCompleted: existing?.isCompleted ?? false
                        )
                        onSave(hw)

                        // Автоматически создаем заметку в календаре на дату сдачи
                        let calendar = Calendar.current
                        let dueDateOnly = calendar.startOfDay(for: dueDate)

                        // Форматируем дату и время для заметки
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale = Locale(identifier: "ru_RU")
                        dateFormatter.dateFormat = "d MMMM, HH:mm"
                        let dueDateFormatted = dateFormatter.string(from: dueDate)

                        let homeworkText = "📝 \(lessonTitle): \(hw.title)\nСдать до: \(dueDateFormatted)"
                        onDayNoteCreated?(dueDateOnly, homeworkText)

                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .environment(\.calendar, Calendar(identifier: .gregorian))
    }
}
