import SwiftUI
import UIKit
import Combine

struct NewsView: View {
    @StateObject private var ratingService = TeacherRatingService.shared
    @StateObject private var contentService = ContentUpdateService.shared
    @State private var showAllTeachers = false
    @State private var currentNewsIndex: Int = 0
    @State private var currentAdIndex: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Карусель новостей/фотографий
                        newsCarousel
                        
                        // Реклама
                        advertisementsSection
                        
                        // Рейтинг преподавателей
                        ratingSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Новости")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .onAppear {
                // Загружаем всех преподавателей из статического списка
                ratingService.loadAllTeachers()
                // Быстрая проверка и обновление контента при открытии
                Task {
                    await contentService.checkAndUpdateIfNeeded()
                }
            }
        }
    }
    
    // MARK: - News Carousel (Карусель новостей)
    
    private var newsCarousel: some View {
        VStack(spacing: 0) {
            if !contentService.newsItems.isEmpty {
                TabView(selection: $currentNewsIndex) {
                    ForEach(0..<contentService.newsItems.count, id: \.self) { index in
                        NewsCard(newsItem: contentService.newsItems[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // Убираем стандартные точки
                .frame(height: 320) // В 2 раза больше чем было (~160)
                
                // Индикаторы страниц (ниже карточки, чтобы не залезали на фотки)
                HStack(spacing: 6) {
                    ForEach(0..<contentService.newsItems.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentNewsIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 4)
            } else {
                // Плейсхолдер при загрузке новостей
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 320)
                    .overlay(
                        VStack {
                            ProgressView()
                                .tint(.white)
                            Text("Загрузка новостей...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 8)
                        }
                    )
            }
        }
    }
    
    // MARK: - Advertisements Section
    
    private var advertisementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Партнёры")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            TabView(selection: $currentAdIndex) {
                ForEach(0..<contentService.advertisements.count, id: \.self) { index in
                    AdvertisementCard(advertisement: contentService.advertisements[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 120)
            .onReceive(Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()) { _ in
                guard !contentService.advertisements.isEmpty else { return }
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    currentAdIndex = (currentAdIndex + 1) % contentService.advertisements.count
                }
            }
        }
    }
    
    // MARK: - Rating Section
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Заголовок
            VStack(alignment: .leading, spacing: 8) {
                Text("Рейтинг преподавателей")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                
                // Статус голосования
                votingStatusBadge
            }
            .padding(.horizontal, 4)
            
            // Топ-3 (особый дизайн)
            if !ratingService.top3.isEmpty {
                top3Section
            }
            
            // Топ-10 (в рамке)
            if !ratingService.top10.isEmpty {
                top10Section
            }
            
            // Кнопка "Все преподаватели"
            allTeachersButton
            
            // Все преподаватели (если развёрнуто)
            if showAllTeachers {
                allTeachersSection
            }
            
            // Остальные (внизу)
            if !ratingService.worst.isEmpty && !showAllTeachers {
                othersSection
            }
        }
    }
    
    // MARK: - All Teachers Button
    
    private var allTeachersButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showAllTeachers.toggle()
            }
        }) {
            HStack {
                Text("Все преподаватели")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                
                Text("(\(ratingService.ratings.count))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Image(systemName: showAllTeachers ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
                    .rotationEffect(.degrees(showAllTeachers ? 0 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Voting Status Badge
    
    private var votingStatusBadge: some View {
        HStack(spacing: 8) {
            // Индикатор
            Circle()
                .fill(ratingService.isVotingOpen ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            // Статус
            Text(ratingService.votingStatusText)
                .font(.caption.weight(.medium))
                .foregroundColor(ratingService.isVotingOpen ? .green : .red)
            
            // Время
            if let timeText = ratingService.timeUntilEventText {
                Text("•")
                    .foregroundColor(.white.opacity(0.3))
                Text(timeText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(ratingService.isVotingOpen ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }
    
    // MARK: - Top 3 Section (Подиум)
    
    private var top3Section: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                Text("Топ-3")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            HStack(spacing: 8) {
                ForEach(Array(ratingService.top3.enumerated()), id: \.element.id) { index, rating in
                    Top3Card(rating: rating, place: index + 1, isVotingOpen: ratingService.isVotingOpen, onVote: { vote in
                        handleVote(for: rating, vote: vote)
                    })
                }
            }
        }
    }
    
    // MARK: - Top 10 Section
    
    private var top10Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                Text("Топ-10")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(ratingService.top10.enumerated()), id: \.element.id) { index, rating in
                    TeacherRow(
                        rating: rating,
                        rank: index + 4, // 4-10
                        style: .top,
                        isVotingOpen: ratingService.isVotingOpen,
                        onVote: { vote in handleVote(for: rating, vote: vote) }
                    )
                    
                    if index < ratingService.top10.count - 1 {
                        Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    }
    
    // MARK: - All Teachers Section
    
    private var allTeachersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Все преподаватели (\(ratingService.ratings.count))")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 0) {
                ForEach(ratingService.sortedByBest) { rating in
                    TeacherRow(
                        rating: rating,
                        rank: nil,
                        style: .normal,
                        isVotingOpen: ratingService.isVotingOpen,
                        onVote: { vote in handleVote(for: rating, vote: vote) }
                    )
                    Divider().background(Color.white.opacity(0.05)).padding(.horizontal, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            )
        }
    }
    
    // MARK: - Others Section (Остальные)
    
    private var othersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.white.opacity(0.6))
                Text("Остальные")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                ForEach(Array(ratingService.worst.prefix(5).enumerated()), id: \.element.id) { index, rating in
                    TeacherRow(
                        rating: rating,
                        rank: nil,
                        style: .normal,
                        isVotingOpen: ratingService.isVotingOpen,
                        onVote: { vote in handleVote(for: rating, vote: vote) }
                    )
                    
                    if index < min(4, ratingService.worst.count - 1) {
                        Divider().background(Color.white.opacity(0.08)).padding(.horizontal, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Actions
    
    private func handleVote(for rating: TeacherRating, vote: VoteType) {
        if rating.userVote == vote {
            ratingService.removeVote(for: rating.teacherName)
        } else {
            ratingService.vote(for: rating.teacherName, vote: vote)
        }
    }
}

// MARK: - Top 3 Card (Карточка для топ-3)

private struct Top3Card: View {
    let rating: TeacherRating
    let place: Int
    let isVotingOpen: Bool
    var onVote: (VoteType) -> Void
    
    private var placeColor: Color {
        switch place {
        case 1: return .yellow
        case 2: return Color(white: 0.75)
        case 3: return .orange
        default: return .gray
        }
    }
    
    private var placeIcon: String {
        switch place {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(place)"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Место
            Text(placeIcon)
                .font(.title2)
            
            // Полное имя
            Text(rating.teacherName)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(minHeight: 36)
            
            // Статистика (всегда видны)
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    Image(systemName: "hand.thumbsup.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green.opacity(0.8))
                    Text("\(rating.likes)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
                HStack(spacing: 2) {
                    Image(systemName: "hand.thumbsdown.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red.opacity(0.8))
                    Text("\(rating.dislikes)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Кнопки голосования (только если открыто)
            if isVotingOpen {
                HStack(spacing: 4) {
                    ForEach(VoteType.allCases, id: \.self) { vote in
                        Button(action: { onVote(vote) }) {
                            Image(systemName: vote.icon)
                                .font(.system(size: 12))
                                .foregroundColor(rating.userVote == vote ? vote.color : .white.opacity(0.5))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(rating.userVote == vote ? vote.color.opacity(0.2) : Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Показываем текущий голос пользователя
                if let userVote = rating.userVote {
                    HStack(spacing: 4) {
                        Image(systemName: userVote.icon)
                            .font(.system(size: 12))
                            .foregroundColor(userVote.color)
                        Text("Ваш голос")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [placeColor.opacity(0.5), placeColor.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: place == 1 ? 2 : 1
                        )
                )
        )
    }
    
}

// MARK: - Teacher Row (Строка преподавателя)

private struct TeacherRow: View {
    let rating: TeacherRating
    let rank: Int?
    let style: RowStyle
    let isVotingOpen: Bool
    var onVote: (VoteType) -> Void
    
    enum RowStyle {
        case top, normal, worst
        
        var rankColor: Color {
            switch self {
            case .top: return .orange
            case .normal: return .white.opacity(0.5)
            case .worst: return .gray
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Ранг
            if let rank = rank {
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(style.rankColor)
                    .frame(width: 24)
            }
            
            // Имя
            VStack(alignment: .leading, spacing: 2) {
                Text(rating.teacherName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Статистика голосов (всегда видна)
                HStack(spacing: 8) {
                    Label("\(rating.likes)", systemImage: "hand.thumbsup.fill")
                        .font(.caption2)
                        .foregroundColor(.green.opacity(0.8))
                    
                    Label("\(rating.neutrals)", systemImage: "plusminus")
                        .font(.caption2)
                        .foregroundColor(.yellow.opacity(0.8))
                    
                    Label("\(rating.dislikes)", systemImage: "hand.thumbsdown.fill")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.8))
                }
            }
            
            Spacer()
            
            // Кнопки голосования или статус
            if isVotingOpen {
                HStack(spacing: 6) {
                    ForEach(VoteType.allCases, id: \.self) { vote in
                        Button(action: { onVote(vote) }) {
                            Image(systemName: vote.icon)
                                .font(.system(size: 14))
                                .foregroundColor(rating.userVote == vote ? vote.color : .white.opacity(0.4))
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(rating.userVote == vote ? vote.color.opacity(0.2) : Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                // Показываем текущий голос пользователя
                if let userVote = rating.userVote {
                    HStack(spacing: 4) {
                        Image(systemName: userVote.icon)
                            .font(.system(size: 14))
                            .foregroundColor(userVote.color)
                        Text("Ваш голос")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(userVote.color.opacity(0.15))
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Advertisement Card

// MARK: - News Card (Карточка новости/фотографии)

private struct NewsCard: View {
    let newsItem: NewsItem
    
    var body: some View {
        ZStack {
            // Фотография (пробуем загрузить из Assets или Bundle)
            // 1. Пробуем загрузить из Assets (с расширением и без)
            if let image = UIImage(named: newsItem.imageName) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else if let image = UIImage(named: "\(newsItem.imageName).jpg") {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            // 2. Пробуем загрузить из Bundle/news (с расширением .jpg)
            else if let imagePath = Bundle.main.path(forResource: newsItem.imageName, ofType: "jpg", inDirectory: "news"),
                     let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            // 3. Пробуем загрузить из Bundle/news (без расширения, но с полным именем)
            else if let imagePath = Bundle.main.path(forResource: newsItem.imageName, ofType: nil, inDirectory: "news"),
                     let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            // 4. Пробуем загрузить напрямую из Bundle (без папки news)
            else if let imagePath = Bundle.main.path(forResource: newsItem.imageName, ofType: "jpg"),
                     let image = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            // 5. Fallback если изображение не найдено
            else {
                ZStack {
                    Color.gray.opacity(0.3)
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Изображение не найдено: \(newsItem.imageName)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            
            // Градиент снизу для текста
            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 120)
            }
            
            // Текст поверх фотографии
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    if let title = newsItem.title {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    if let description = newsItem.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Advertisement Card (Плейсхолдер для рекламы)

private struct AdvertisementCard: View {
    let advertisement: Advertisement
    
    var body: some View {
        HStack(spacing: 16) {
            // Иконка
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Image(systemName: "megaphone.fill")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.title2)
            }
            
            // Текст
            VStack(alignment: .leading, spacing: 6) {
                Text(advertisement.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                
                Text(advertisement.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Стрелка
            Image(systemName: "arrow.right.circle.fill")
                .font(.title2)
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.15), Color.blue.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

