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

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 220, height: 220)
                    .blur(radius: 12)

                Circle()
                    .fill(Color.white)
                    .frame(width: 140, height: 140)
                    .shadow(color: .white.opacity(0.4), radius: 24, x: 0, y: 0)

                Image(systemName: "graduationcap.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.black)
            }

            VStack(spacing: 8) {
                Text("Добро пожаловать в")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)

                Text("«Мой МПТ»")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
            }

            Text("Мы рады, что вы выбрали именно этот техникум для обучения. Это приложение поможет быстро и удобно смотреть расписание и изменения.")
                .font(.body)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Отлично")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
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
