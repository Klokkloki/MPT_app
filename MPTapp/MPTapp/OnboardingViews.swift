import SwiftUI

struct OnboardingFlowView: View {
    enum Step {
        case welcome
        case selectSpecialty
        case selectGroup
    }

    @State private var step: Step = .welcome
    @State private var selectedSpecialty: Specialty?
    @State private var selectedGroup: Group?
    
    @StateObject private var viewModel = ScheduleViewModel()

    @AppStorage("selectedSpecialtyId") private var storedSpecialtyId: String?
    @AppStorage("selectedGroupId") private var storedGroupId: String?
    @AppStorage("selectedSpecialtyName") private var storedSpecialtyName: String?
    @AppStorage("selectedGroupName") private var storedGroupName: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch step {
            case .welcome:
                WelcomeScreen {
                    withAnimation(.spring()) {
                        step = .selectSpecialty
                    }
                }
            case .selectSpecialty:
                SelectSpecialtyScreen(
                    viewModel: viewModel,
                    selectedSpecialty: $selectedSpecialty,
                    onNext: {
                        guard selectedSpecialty != nil else { return }
                        withAnimation(.spring()) {
                            step = .selectGroup
                        }
                    },
                    onBack: {
                        withAnimation(.spring()) {
                            step = .welcome
                        }
                    }
                )
            case .selectGroup:
                SelectGroupScreen(
                    viewModel: viewModel,
                    selectedSpecialty: selectedSpecialty,
                    selectedGroup: $selectedGroup,
                    onFinish: {
                        guard let specialty = selectedSpecialty,
                              let group = selectedGroup else { return }
                        storedSpecialtyId = specialty.id
                        storedSpecialtyName = specialty.name
                        storedGroupId = group.id
                        storedGroupName = group.name
                        
                        // Загружаем расписание
                        Task {
                            // Загружаем расписание - оно автоматически сохранится в кеш
                            await viewModel.loadSchedule(for: group)
                            // Замены не критичны для первого запуска, загружаем в фоне
                            Task.detached(priority: .background) {
                                await viewModel.loadReplacements(for: group)
                            }
                        }
                    },
                    onBack: {
                        withAnimation(.spring()) {
                            step = .selectSpecialty
                        }
                    }
                )
            }
        }
        .task {
            await viewModel.loadSpecialties()
        }
    }
}

private struct WelcomeScreen: View {
    var onContinue: () -> Void
    
    @State private var animateColor = 0.0
    @State private var animateLogo = false
    @State private var animateText = false
    @State private var animateButton = false

    var body: some View {
        ZStack {
            // Статичный черный фон
            Color.black
                .ignoresSafeArea()
            
            // Декоративные круги на фоне с плавной сменой цвета
            GeometryReader { geo in
                // Левый верхний угол - плавно переливается от синего к фиолетовому
                let circle1Color = interpolateColor(from: UIColor.blue, to: UIColor.systemPurple, progress: animateColor)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(circle1Color).opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -50)
                    .blur(radius: 60)
                
                // Правый нижний угол - плавно переливается от фиолетового к синему
                let circle2Color = interpolateColor(from: UIColor.systemPurple, to: UIColor.blue, progress: animateColor)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(circle2Color).opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: geo.size.width - 100, y: geo.size.height - 200)
                    .blur(radius: 50)
            }
            
            VStack(spacing: 40) {
                Spacer()

                // Логотип с анимацией
                ZStack {
                    // Внешнее свечение
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.1), Color.clear],
                                center: .center,
                                startRadius: 60,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                        .scaleEffect(animateLogo ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateLogo)
                    
                    // Кольца
                    ForEach(0..<3) { i in
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                            .frame(width: CGFloat(160 + i * 40), height: CGFloat(160 + i * 40))
                            .scaleEffect(animateLogo ? 1.05 : 0.95)
                            .animation(.easeInOut(duration: 2).delay(Double(i) * 0.2).repeatForever(autoreverses: true), value: animateLogo)
                    }
                    
                    // Основной круг с логотипом
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 130, height: 130)
                        .shadow(color: .white.opacity(0.3), radius: 30, x: 0, y: 0)
                        .overlay(
                            Image(systemName: "graduationcap.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.black)
                        )
                        .scaleEffect(animateLogo ? 1.0 : 0.8)
                        .opacity(animateLogo ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateLogo)
                }

                // Текст с анимацией
                VStack(spacing: 12) {
                    Text("Добро пожаловать")
                        .font(.title3.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: animateText ? 0 : 20)
                        .opacity(animateText ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateText)

                    Text("МПТ им. Плеханова")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(y: animateText ? 0 : 20)
                        .opacity(animateText ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateText)
                }

                // Описание
                VStack(spacing: 16) {
                    Text("Ваш помощник в учёбе")
                        .font(.headline.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("Расписание, домашние задания, новости колледжа — всё в одном месте")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 40)
                .offset(y: animateText ? 0 : 20)
                .opacity(animateText ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateText)

                Spacer()

                // Кнопка с анимацией
                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Text("Продолжить")
                            .font(.headline.weight(.semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                    )
                }
                .padding(.horizontal, 28)
                .scaleEffect(animateButton ? 1 : 0.9)
                .opacity(animateButton ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: animateButton)
                
                // Версия приложения
                Text("Версия 2.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 24)
                    .opacity(animateButton ? 1 : 0)
                    .animation(.easeOut.delay(1), value: animateButton)
            }
        }
        .onAppear {
            animateLogo = true
            animateText = true
            animateButton = true
            
            // Плавная анимация изменения цвета кругов от синего к фиолетовому и обратно
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateColor = 1.0
            }
        }
    }
}

private struct SelectSpecialtyScreen: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var selectedSpecialty: Specialty?
    var onNext: () -> Void
    var onBack: () -> Void
    
    @State private var animateContent = false

    var body: some View {
        ZStack {
            // Фон с градиентом
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black,
                    Color(red: 0.1, green: 0.05, blue: 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Декоративный элемент
            VStack {
                HStack {
                    Spacer()
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.purple.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: 100, y: -100)
                        .blur(radius: 40)
                }
                Spacer()
            }
            
            VStack(spacing: 0) {
                // Верхняя панель
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Назад")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    Spacer()
                    
                    // Индикатор шага
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()
                
                // Иконка
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(animateContent ? 1 : 0.8)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateContent)
                .padding(.bottom, 24)

                // Заголовок
                VStack(spacing: 8) {
                    Text("Выберите")
                        .font(.title2.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("специальность")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                }
                .offset(y: animateContent ? 0 : 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
                .padding(.bottom, 32)

                // Выбор специальности
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("Загрузка специальностей...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 40)
                    } else {
                        Menu {
                            ForEach(viewModel.specialties) { spec in
                                Button(action: { 
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedSpecialty = spec 
                                    }
                                }) {
                                    Text(spec.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedSpecialty == nil ? "list.bullet" : "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(selectedSpecialty == nil ? .white.opacity(0.5) : .green)
                                
                                Text(selectedSpecialty?.name ?? "Нажмите для выбора")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(selectedSpecialty == nil ? .white.opacity(0.5) : .white)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                selectedSpecialty == nil ? Color.white.opacity(0.1) : Color.green.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .offset(y: animateContent ? 0 : 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)

                Spacer()

                // Кнопка продолжить
                VStack(spacing: 16) {
                    Button(action: onNext) {
                        HStack(spacing: 10) {
                            Text("Продолжить")
                                .font(.headline.weight(.semibold))
                            Image(systemName: "arrow.right")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundColor(selectedSpecialty == nil ? .white.opacity(0.4) : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(selectedSpecialty == nil ? Color.white.opacity(0.15) : Color.white)
                                .shadow(color: selectedSpecialty == nil ? .clear : .white.opacity(0.2), radius: 15, x: 0, y: 8)
                        )
                    }
                    .disabled(selectedSpecialty == nil)
                    .padding(.horizontal, 24)
                    
                    Text("Шаг 1 из 2")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                .offset(y: animateContent ? 0 : 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            animateContent = true
        }
    }
}

private struct SelectGroupScreen: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let selectedSpecialty: Specialty?
    @Binding var selectedGroup: Group?

    var onFinish: () -> Void
    var onBack: () -> Void
    
    @State private var animateContent = false

    var body: some View {
        ZStack {
            // Фон с градиентом
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.15),
                    Color.black,
                    Color(red: 0.1, green: 0.05, blue: 0.1)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .ignoresSafeArea()
            
            // Декоративный элемент
            VStack {
                Spacer()
                HStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.blue.opacity(0.15), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .offset(x: -100, y: 100)
                        .blur(radius: 40)
                    Spacer()
                }
            }
            
            VStack(spacing: 0) {
                // Верхняя панель
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Назад")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                    Spacer()
                    
                    // Индикатор шага
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()
                
                // Иконка
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 45))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .scaleEffect(animateContent ? 1 : 0.8)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateContent)
                .padding(.bottom, 24)

                // Заголовок
                VStack(spacing: 8) {
                    Text("Выберите")
                        .font(.title2.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text("учебную группу")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                    
                    // Показываем выбранную специальность
                    if let specialty = selectedSpecialty {
                        Text(specialty.name)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                            .padding(.top, 8)
                    }
                }
                .offset(y: animateContent ? 0 : 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
                .padding(.bottom, 32)

                // Выбор группы
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                            Text("Загрузка групп...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 40)
                    } else if viewModel.groups.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundColor(.orange)
                            Text("Группы не найдены")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 40)
                    } else {
                        Menu {
                            ForEach(viewModel.groups) { group in
                                Button(action: { 
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedGroup = group 
                                    }
                                }) {
                                    Text(group.name)
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedGroup == nil ? "person.crop.circle" : "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(selectedGroup == nil ? .white.opacity(0.5) : .green)
                                
                                Text(selectedGroup?.name ?? "Нажмите для выбора")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(selectedGroup == nil ? .white.opacity(0.5) : .white)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                selectedGroup == nil ? Color.white.opacity(0.1) : Color.green.opacity(0.3),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                        .padding(.horizontal, 24)
                        
                        // Количество групп
                        Text("\(viewModel.groups.count) групп доступно")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .offset(y: animateContent ? 0 : 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)

                Spacer()

                // Кнопка завершения
                VStack(spacing: 16) {
                    Button(action: onFinish) {
                        HStack(spacing: 10) {
                            Text("Начать")
                                .font(.headline.weight(.semibold))
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.bold))
                        }
                        .foregroundColor(selectedGroup == nil ? .white.opacity(0.4) : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            Capsule()
                                .fill(selectedGroup == nil ? Color.white.opacity(0.15) : Color.white)
                                .shadow(color: selectedGroup == nil ? .clear : .white.opacity(0.2), radius: 15, x: 0, y: 8)
                        )
                    }
                    .disabled(selectedGroup == nil)
                    .padding(.horizontal, 24)
                    
                    Text("Шаг 2 из 2")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                .offset(y: animateContent ? 0 : 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: animateContent)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            animateContent = true
        }
        .task {
            if let specialty = selectedSpecialty {
                await viewModel.loadGroups(for: specialty)
            }
        }
        .onChange(of: selectedSpecialty) { _, newValue in
            if let specialty = newValue {
                Task {
                    await viewModel.loadGroups(for: specialty)
                }
            }
        }
    }
}

// MARK: - Helper Functions

/// Интерполирует цвет между двумя цветами на основе прогресса (0.0 - 1.0)
private func interpolateColor(from: UIColor, to: UIColor, progress: Double) -> UIColor {
    var fromRed: CGFloat = 0
    var fromGreen: CGFloat = 0
    var fromBlue: CGFloat = 0
    var fromAlpha: CGFloat = 0
    
    var toRed: CGFloat = 0
    var toGreen: CGFloat = 0
    var toBlue: CGFloat = 0
    var toAlpha: CGFloat = 0
    
    from.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
    to.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
    
    let clampedProgress = max(0.0, min(1.0, progress))
    
    let red = fromRed + (toRed - fromRed) * CGFloat(clampedProgress)
    let green = fromGreen + (toGreen - fromGreen) * CGFloat(clampedProgress)
    let blue = fromBlue + (toBlue - fromBlue) * CGFloat(clampedProgress)
    let alpha = fromAlpha + (toAlpha - fromAlpha) * CGFloat(clampedProgress)
    
    return UIColor(red: red, green: green, blue: blue, alpha: alpha)
}
