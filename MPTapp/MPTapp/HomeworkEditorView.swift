import SwiftUI

struct HomeworkEditorView: View {
    let lesson: Lesson
    let lessonTitle: String      // Название предмета (может быть числитель или знаменатель)
    let lessonTeacher: String    // ФИО преподавателя (может быть числитель или знаменатель)
    let lessonId: UUID           // ID для сохранения ДЗ
    let existing: Homework?

    var onSave: (Homework) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var shouldRemind: Bool = false

    // Основной инициализатор с отдельным lessonTitle, lessonTeacher и lessonId
    init(lesson: Lesson, lessonTitle: String, lessonTeacher: String, lessonId: UUID, existing: Homework?, onSave: @escaping (Homework) -> Void) {
        self.lesson = lesson
        self.lessonTitle = lessonTitle
        self.lessonTeacher = lessonTeacher
        self.lessonId = lessonId
        self.existing = existing
        self.onSave = onSave

        _title = State(initialValue: existing?.title ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
        _dueDate = State(initialValue: existing?.dueDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        _shouldRemind = State(initialValue: existing?.shouldRemind ?? false)
    }
    
    // Удобный инициализатор для обычных пар
    init(lesson: Lesson, existing: Homework?, onSave: @escaping (Homework) -> Void) {
        self.init(lesson: lesson, lessonTitle: lesson.title, lessonTeacher: lesson.teacher, lessonId: lesson.id, existing: existing, onSave: onSave)
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


