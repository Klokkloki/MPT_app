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
    
    @State private var animateGradient = false
    @State private var animateLogo = false
    @State private var animateText = false
    @State private var animateButton = false

    var body: some View {
        ZStack {
            // Анимированный градиентный фон
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color.black,
                    Color(red: 0.05, green: 0.1, blue: 0.15)
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animateGradient)
            
            // Декоративные круги на фоне
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.blue.opacity(0.15), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -100, y: -50)
                    .blur(radius: 60)
                
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.purple.opacity(0.1), Color.clear],
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

                    Text("Мой МПТ")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
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
            animateGradient = true
            animateLogo = true
            animateText = true
            animateButton = true
        }
    }
}

private struct SelectSpecialtyScreen: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Binding var selectedSpecialty: Specialty?
    var onNext: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Text("Выберите свою")
                    .font(.title.weight(.semibold))
                    .foregroundColor(.white)
                Text("специальность")
                    .font(.title.weight(.semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                } else {
                    Menu {
                        ForEach(viewModel.specialties) { spec in
                            Button(action: { selectedSpecialty = spec }) {
                                Text(spec.name)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedSpecialty?.name ?? "Выберите специальность")
                                .foregroundColor(selectedSpecialty == nil ? .white.opacity(0.5) : .white)
                                .lineLimit(2)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            Button(action: onNext) {
                Text("Продолжить")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.black.opacity(selectedSpecialty == nil ? 0.4 : 1))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(selectedSpecialty == nil ? 0.3 : 1))
                    )
            }
            .disabled(selectedSpecialty == nil)
            .padding(.horizontal, 24)

            Button(action: onBack) {
                Text("Назад")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private struct SelectGroupScreen: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let selectedSpecialty: Specialty?
    @Binding var selectedGroup: Group?

    var onFinish: () -> Void
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                Text("Выберите свою")
                    .font(.title.weight(.semibold))
                    .foregroundColor(.white)
                Text("учебную группу")
                    .font(.title.weight(.semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                } else {
                    Menu {
                        ForEach(viewModel.groups) { group in
                            Button(action: { selectedGroup = group }) {
                                Text(group.name)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedGroup?.name ?? "Выберите группу")
                                .foregroundColor(selectedGroup == nil ? .white.opacity(0.5) : .white)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .padding(.horizontal, 24)
                }
            }

            Spacer()

            Button(action: onFinish) {
                Text("Продолжить")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.black.opacity(selectedGroup == nil ? 0.4 : 1))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(selectedGroup == nil ? 0.3 : 1))
                    )
            }
            .disabled(selectedGroup == nil)
            .padding(.horizontal, 24)

            Button(action: onBack) {
                Text("Назад")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
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
