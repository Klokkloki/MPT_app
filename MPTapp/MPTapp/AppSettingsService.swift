import SwiftUI

// MARK: - App Settings Service
/// Сервис для хранения пользовательских настроек интерфейса

class AppSettingsService: ObservableObject {
    static let shared = AppSettingsService()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private let textScaleKey = "appTextScale"
    private let numeratorColorIndexKey = "numeratorColorIndex"
    private let denominatorColorIndexKey = "denominatorColorIndex"
    private let numeratorImagePathKey = "numeratorCustomImagePath"
    private let denominatorImagePathKey = "denominatorCustomImagePath"
    
    // MARK: - Preset Colors (индексы для сохранения)
    
    static let colorPresets: [(name: String, color: Color)] = [
        ("Оранжевый", Color.orange),      // 0
        ("Красный", Color.red),           // 1
        ("Розовый", Color.pink),          // 2
        ("Фиолетовый", Color.purple),     // 3
        ("Синий", Color.blue),            // 4
        ("Голубой", Color.cyan),          // 5
        ("Бирюзовый", Color.teal),        // 6
        ("Зелёный", Color.green),         // 7
        ("Мятный", Color.mint),           // 8
        ("Жёлтый", Color.yellow),         // 9
        ("Индиго", Color.indigo)          // 10
    ]
    
    // MARK: - Published Properties
    
    /// Масштаб текста (0.8 - 1.4, по умолчанию 1.0)
    @Published var textScale: Double {
        didSet {
            defaults.set(textScale, forKey: textScaleKey)
        }
    }
    
    /// Индекс цвета числителя
    @Published var numeratorColorIndex: Int {
        didSet {
            defaults.set(numeratorColorIndex, forKey: numeratorColorIndexKey)
        }
    }
    
    /// Индекс цвета знаменателя
    @Published var denominatorColorIndex: Int {
        didSet {
            defaults.set(denominatorColorIndex, forKey: denominatorColorIndexKey)
        }
    }
    
    /// Кастомное фото для числителя
    @Published var numeratorCustomImage: UIImage? {
        didSet {
            if let image = numeratorCustomImage {
                saveCustomImage(image, for: .numerator)
            } else {
                deleteCustomImage(for: .numerator)
            }
        }
    }
    
    /// Кастомное фото для знаменателя
    @Published var denominatorCustomImage: UIImage? {
        didSet {
            if let image = denominatorCustomImage {
                saveCustomImage(image, for: .denominator)
            } else {
                deleteCustomImage(for: .denominator)
            }
        }
    }
    
    /// Цвет числителя (по умолчанию оранжевый)
    var numeratorColor: Color {
        get {
            guard numeratorColorIndex >= 0 && numeratorColorIndex < Self.colorPresets.count else {
                return .orange
            }
            return Self.colorPresets[numeratorColorIndex].color
        }
        set {
            if let index = Self.colorPresets.firstIndex(where: { $0.color == newValue }) {
                numeratorColorIndex = index
            }
        }
    }
    
    /// Цвет знаменателя (по умолчанию голубой)
    var denominatorColor: Color {
        get {
            guard denominatorColorIndex >= 0 && denominatorColorIndex < Self.colorPresets.count else {
                return .cyan
            }
            return Self.colorPresets[denominatorColorIndex].color
        }
        set {
            if let index = Self.colorPresets.firstIndex(where: { $0.color == newValue }) {
                denominatorColorIndex = index
            }
        }
    }
    
    // MARK: - Init
    
    private init() {
        // Инициализируем все stored properties
        let savedScale = defaults.double(forKey: textScaleKey)
        self.textScale = savedScale > 0 ? savedScale : 1.0
        
        // Загружаем сохраненные цвета или используем значения по умолчанию
        let savedNumeratorIndex = defaults.object(forKey: numeratorColorIndexKey) as? Int
        let savedDenominatorIndex = defaults.object(forKey: denominatorColorIndexKey) as? Int
        self.numeratorColorIndex = savedNumeratorIndex ?? 0  // оранжевый по умолчанию
        self.denominatorColorIndex = savedDenominatorIndex ?? 5  // голубой по умолчанию
        
        // Загружаем кастомные фото (если есть)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.numeratorCustomImage = self.loadCustomImage(for: .numerator)
            self.denominatorCustomImage = self.loadCustomImage(for: .denominator)
        }
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        textScale = 1.0
        numeratorColorIndex = 0  // оранжевый
        denominatorColorIndex = 5  // голубой
        // При сбросе настроек также удаляем кастомные фото
        removeCustomImage(for: .numerator)
        removeCustomImage(for: .denominator)
    }
    
    // MARK: - Gradient Colors
    
    /// Градиент для числителя
    var numeratorGradient: [Color] {
        [numeratorColor, numeratorColor.opacity(0.7)]
    }
    
    /// Градиент для знаменателя
    var denominatorGradient: [Color] {
        [denominatorColor, denominatorColor.opacity(0.7)]
    }
    
    // MARK: - Scaled Fonts
    
    func scaledFont(_ font: Font.TextStyle) -> Font {
        switch font {
        case .largeTitle:
            return .system(size: 34 * textScale, weight: .bold)
        case .title:
            return .system(size: 28 * textScale, weight: .bold)
        case .title2:
            return .system(size: 22 * textScale, weight: .semibold)
        case .title3:
            return .system(size: 20 * textScale, weight: .semibold)
        case .headline:
            return .system(size: 17 * textScale, weight: .semibold)
        case .body:
            return .system(size: 17 * textScale)
        case .callout:
            return .system(size: 16 * textScale)
        case .subheadline:
            return .system(size: 15 * textScale)
        case .footnote:
            return .system(size: 13 * textScale)
        case .caption:
            return .system(size: 12 * textScale)
        case .caption2:
            return .system(size: 11 * textScale)
        @unknown default:
            return .system(size: 17 * textScale)
        }
    }
    
    // MARK: - Color Selection Helpers
    
    func isColorSelected(_ color: Color, for weekType: WeekType) -> Bool {
        guard let index = Self.colorPresets.firstIndex(where: { $0.color == color }) else {
            return false
        }
        return weekType == .numerator ? numeratorColorIndex == index : denominatorColorIndex == index
    }
    
    func setColor(_ index: Int, for weekType: WeekType) {
        guard index >= 0 && index < Self.colorPresets.count else { return }

        if weekType == .numerator {
            numeratorColorIndex = index
        } else {
            denominatorColorIndex = index
        }
    }
    
    /// Проверка, является ли цвет цветом по умолчанию
    func isDefaultColor(_ index: Int, for weekType: WeekType) -> Bool {
        let defaultIndex = weekType == .numerator ? 0 : 5
        return index == defaultIndex
    }
    
    // MARK: - Week Type Calculation
    
    /// Определяем тип недели автоматически по дате
    /// Семестр обычно начинается 1 сентября с числителя
    /// После каждого воскресенья (00:00) неделя меняется
    static func currentWeekType(for date: Date = Date()) -> WeekType {
        let calendar = Calendar.current
        
        // Базовая дата: 1 сентября 2025 года - числитель
        // Можно изменить если нужно синхронизировать с реальным расписанием колледжа
        var components = DateComponents()
        components.year = 2025
        components.month = 9
        components.day = 1
        let baseDate = calendar.date(from: components) ?? Date()
        
        // Считаем количество недель от базовой даты
        let weeksBetween = calendar.dateComponents([.weekOfYear], from: baseDate, to: date).weekOfYear ?? 0
        
        // Чётные недели - числитель, нечётные - знаменатель
        return (weeksBetween % 2 == 0) ? .numerator : .denominator
    }
    
    /// Текущий тип недели
    var currentWeekType: WeekType {
        Self.currentWeekType()
    }
    
    /// Градиент для текущей недели
    var currentWeekGradient: [Color] {
        currentWeekType == .numerator ? numeratorGradient : denominatorGradient
    }
    
    /// Цвет для текущей недели
    var currentWeekColor: Color {
        currentWeekType == .numerator ? numeratorColor : denominatorColor
    }
    
    // MARK: - Custom Images Management
    
    /// Сохранить кастомное изображение
    private func saveCustomImage(_ image: UIImage, for weekType: WeekType) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let filename = weekType == .numerator ? "numerator_custom.jpg" : "denominator_custom.jpg"
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        let key = weekType == .numerator ? numeratorImagePathKey : denominatorImagePathKey
        
        // Сохраняем изображение
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            try? imageData.write(to: fileURL)
            defaults.set(fileURL.path, forKey: key)
        }
    }
    
    /// Загрузить кастомное изображение
    private func loadCustomImage(for weekType: WeekType) -> UIImage? {
        let key = weekType == .numerator ? numeratorImagePathKey : denominatorImagePathKey
        
        guard let imagePath = defaults.string(forKey: key),
              FileManager.default.fileExists(atPath: imagePath),
              let image = UIImage(contentsOfFile: imagePath) else {
            return nil
        }
        
        return image
    }
    
    /// Удалить кастомное изображение
    private func deleteCustomImage(for weekType: WeekType) {
        let key = weekType == .numerator ? numeratorImagePathKey : denominatorImagePathKey
        
        if let imagePath = defaults.string(forKey: key) {
            try? FileManager.default.removeItem(atPath: imagePath)
            defaults.removeObject(forKey: key)
        }
    }
    
    /// Удалить кастомное изображение (публичный метод)
    func removeCustomImage(for weekType: WeekType) {
        if weekType == .numerator {
            numeratorCustomImage = nil
        } else {
            denominatorCustomImage = nil
        }
    }
    
    /// Получить кастомное изображение для текущего типа недели
    var currentWeekCustomImage: UIImage? {
        currentWeekType == .numerator ? numeratorCustomImage : denominatorCustomImage
    }
}
