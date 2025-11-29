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
        // Загружаем масштаб
        let savedScale = defaults.double(forKey: textScaleKey)
        self.textScale = savedScale > 0 ? savedScale : 1.0
        
        // Загружаем индексы цветов (с проверкой на -1 для первого запуска)
        let savedNumeratorIndex = defaults.object(forKey: numeratorColorIndexKey) as? Int
        let savedDenominatorIndex = defaults.object(forKey: denominatorColorIndexKey) as? Int
        
        self.numeratorColorIndex = savedNumeratorIndex ?? 0  // 0 = оранжевый по умолчанию
        self.denominatorColorIndex = savedDenominatorIndex ?? 5  // 5 = голубой по умолчанию
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        textScale = 1.0
        numeratorColorIndex = 0  // оранжевый
        denominatorColorIndex = 5  // голубой
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
}
