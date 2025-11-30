import SwiftUI
import UIKit
import Combine

struct NewsView: View {
    @StateObject private var ratingService = TeacherRatingService.shared
    @StateObject private var contentService = ContentUpdateService.shared
    @State private var showAllTeachers = false
    @State private var currentNewsIndex: Int = 0
    @State private var selectedCategory: AdCategory? = nil
    @State private var expandedAdId: UUID? = nil
    @State private var expandedCollectionId: String? = nil  // Для подборок ресурсов
    @State private var showAllRecommendations = false  // Показать все рекомендации
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Карусель новостей/фотографий
                        newsCarousel
                        
                        // Подборки ресурсов (закреплённые плашки)
                        if !contentService.resourceCollections.isEmpty {
                            resourceCollectionsSection
                        }
                        
                        // Рекомендации (новый дизайн)
                        recommendationsSection
                        
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
    
    // MARK: - Resource Collections Section (Подборки ресурсов)
    
    private var resourceCollectionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Подборки")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    
                    Text("Полезные ресурсы по направлениям")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Карточки подборок
            LazyVStack(spacing: 12) {
                ForEach(contentService.resourceCollections, id: \.id) { collection in
                    ResourceCollectionCard(
                        collection: collection,
                        isExpanded: expandedCollectionId == collection.id,
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                expandedCollectionId = expandedCollectionId == collection.id ? nil : collection.id
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - News Carousel (Карусель новостей)
    
    private var newsCarousel: some View {
        VStack(spacing: 12) {
            if !contentService.newsItems.isEmpty {
                // TabView для правильного отслеживания индекса
                TabView(selection: $currentNewsIndex) {
                    ForEach(Array(contentService.newsItems.enumerated()), id: \.element.id) { index, item in
                        NewsCard(newsItem: item)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                // Индикаторы страниц (анимированные)
                HStack(spacing: 8) {
                    ForEach(0..<contentService.newsItems.count, id: \.self) { index in
                        Capsule()
                            .fill(Color.white.opacity(index == currentNewsIndex ? 1 : 0.3))
                            .frame(width: index == currentNewsIndex ? 20 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentNewsIndex)
                .padding(.top, 4)
            } else {
                // Плейсхолдер при загрузке новостей
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 280)
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.2)
                            Text("Загрузка новостей...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    )
            }
        }
    }
    
    // MARK: - Recommendations Section (Рекомендации)
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок секции
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Рекомендации")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    
                    Text("Полезные ресурсы для студентов")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Количество рекомендаций
                Text("\(filteredAds.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
            .padding(.horizontal, 4)
            
            // Фильтр по категориям
            categoryFilter
            
            // Если выбрано "Все" — показываем свёрнутый вид с кнопкой
            if selectedCategory == nil && !showAllRecommendations {
                // Показываем только первые 3 (закреплённые)
                LazyVStack(spacing: 12) {
                    ForEach(filteredAds.prefix(3)) { ad in
                        RecommendationCard(
                            advertisement: ad,
                            isExpanded: expandedAdId == ad.id,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    expandedAdId = expandedAdId == ad.id ? nil : ad.id
                                }
                            }
                        )
                    }
                }
                
                // Кнопка "Показать все"
                if filteredAds.count > 3 {
                    showAllButton
                }
            } else {
                // Показываем все рекомендации
                LazyVStack(spacing: 12) {
                    ForEach(filteredAds) { ad in
                        RecommendationCard(
                            advertisement: ad,
                            isExpanded: expandedAdId == ad.id,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    expandedAdId = expandedAdId == ad.id ? nil : ad.id
                                }
                            }
                        )
                    }
                }
                
                // Кнопка "Свернуть" (только если выбрано "Все")
                if selectedCategory == nil && showAllRecommendations {
                    collapseButton
                }
            }
        }
    }
    
    // Кнопка "Показать все"
    private var showAllButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showAllRecommendations = true
            }
        }) {
            HStack {
                Text("Показать все")
                    .font(.subheadline.weight(.medium))
                
                Text("(\(filteredAds.count - 3) ещё)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
            }
            .foregroundColor(.white)
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
    
    // Кнопка "Свернуть"
    private var collapseButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showAllRecommendations = false
                expandedAdId = nil  // Сворачиваем все карточки
            }
        }) {
            HStack {
                Text("Свернуть")
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                Image(systemName: "chevron.up.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.6))
            }
            .foregroundColor(.white)
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
    
    // Фильтрованные рекламы
    private var filteredAds: [Advertisement] {
        let ads = contentService.advertisements
        if let category = selectedCategory {
            return ads.filter { $0.category == category }
        }
        // Сначала закреплённые, потом остальные
        return ads.sorted { $0.isPinned && !$1.isPinned }
    }
    
    // Фильтр категорий
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Кнопка "Все"
                CategoryFilterButton(
                    title: "Все",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: .white
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCategory = nil
                        showAllRecommendations = false  // Сбрасываем при переключении на "Все"
                    }
                }
                
                // Кнопки категорий (только те, что есть в рекламе)
                ForEach(availableCategories, id: \.self) { category in
                    CategoryFilterButton(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category,
                        color: category.defaultColor
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // Доступные категории (только те, что есть в рекламе)
    private var availableCategories: [AdCategory] {
        let categories = Set(contentService.advertisements.map { $0.category })
        return AdCategory.allCases.filter { categories.contains($0) }
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

// MARK: - Category Filter Button

private struct CategoryFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recommendation Card (Новая карточка рекомендации)

private struct RecommendationCard: View {
    let advertisement: Advertisement
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    
    @Environment(\.openURL) private var openURL
    
    // Цвет карточки
    private var cardColor: Color {
        if let colors = advertisement.gradientColors, let first = colors.first {
            return Color(hex: first) ?? advertisement.category.defaultColor
        }
        return advertisement.category.defaultColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Основная часть карточки (всегда видна)
            mainContent
            
            // Раскрывающаяся часть
            if isExpanded {
                expandedContent
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardColor.opacity(0.25),
                            cardColor.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [cardColor.opacity(0.4), cardColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // Основной контент карточки
    private var mainContent: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 14) {
                // Иконка
                iconView
                
                // Текст
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(advertisement.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        // Теги
                        if let tags = advertisement.tags, !tags.isEmpty {
                            ForEach(tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(tagColor(for: tag))
                                    )
                            }
                        }
                    }
                    
                    // Подзаголовок или краткое описание
                    Text(advertisement.subtitle ?? advertisement.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(isExpanded ? 10 : 1)
                }
                
                Spacer()
                
                // Стрелка раскрытия
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 0 : 0))
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
    
    // Раскрытый контент
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Разделитель
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Полное описание
            Text(advertisement.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
                .padding(.horizontal, 16)
            
            // Категория
            HStack(spacing: 6) {
                Image(systemName: advertisement.category.icon)
                    .font(.system(size: 11))
                Text(advertisement.category.displayName)
                    .font(.caption)
            }
            .foregroundColor(cardColor)
            .padding(.horizontal, 16)
            
            // Кнопка перехода
            if let urlString = advertisement.url, let url = URL(string: urlString) {
                Button(action: { openURL(url) }) {
                    HStack {
                        Text("Перейти")
                            .font(.subheadline.weight(.semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [cardColor, cardColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
            }
            
            Spacer().frame(height: 4)
        }
        .padding(.bottom, 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // Иконка (48x48, рекомендуемый размер изображения: 96x96 или 144x144 для @2x/@3x)
    @ViewBuilder
    private var iconView: some View {
        ZStack {
            // Фон иконки (показывается если нет фото)
            if advertisement.iconName == nil || UIImage(named: advertisement.iconName ?? "") == nil {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [cardColor.opacity(0.6), cardColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
            }
            
            // Приоритет: фото из Assets > эмодзи > системная иконка
            if let iconName = advertisement.iconName, let image = UIImage(named: iconName) {
                // Фото из Assets (заполняет всю иконку)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if let emoji = advertisement.iconEmoji {
                // Эмодзи
                Text(emoji)
                    .font(.system(size: 24))
            } else {
                // Системная иконка по категории
                Image(systemName: advertisement.category.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 48, height: 48)
    }
    
    // Цвет тега
    private func tagColor(for tag: String) -> Color {
        let lowercased = tag.lowercased()
        if lowercased.contains("бесплатно") || lowercased.contains("free") {
            return .green
        } else if lowercased.contains("скидка") || lowercased.contains("sale") {
            return .orange
        } else if lowercased.contains("новое") || lowercased.contains("new") {
            return .blue
        } else if lowercased.contains("топ") || lowercased.contains("hot") {
            return .red
        }
        return .purple
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - News Card (Карточка новости/фотографии)

private struct NewsCard: View {
    let newsItem: NewsItem
    
    // Загрузка изображения
    private var loadedImage: UIImage? {
        // 1. Из Assets
        if let image = UIImage(named: newsItem.imageName) { return image }
        if let image = UIImage(named: "\(newsItem.imageName).jpg") { return image }
        
        // 2. Из Bundle/news
        let extensions = ["jpg", "jpeg", "png", "webp"]
        for ext in extensions {
            if let path = Bundle.main.path(forResource: newsItem.imageName, ofType: ext, inDirectory: "news"),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
            if let path = Bundle.main.path(forResource: newsItem.imageName, ofType: ext),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
        }
        
        // 3. Без расширения
        if let path = Bundle.main.path(forResource: newsItem.imageName, ofType: nil, inDirectory: "news"),
           let image = UIImage(contentsOfFile: path) {
            return image
        }
        
        return nil
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Фотография
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    // Fallback с инструкцией
                    ZStack {
                        LinearGradient(
                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.5))
                            
                            VStack(spacing: 8) {
                                Text("Изображение не загружено")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("Попробуйте очистить кеш в настройках")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "gear")
                                    .font(.caption2)
                                Text("Настройки → Кеш → Очистить")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                        .padding()
                    }
                }
                
                // Градиент снизу для текста (более плавный)
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)
                }
                
                // Текст поверх фотографии (внутри изображения)
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = newsItem.title {
                            Text(title)
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        }
                        if let description = newsItem.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
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

// MARK: - Resource Collection Card (Карточка подборки ресурсов)

private struct ResourceCollectionCard: View {
    let collection: ResourceCollection
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    
    @Environment(\.openURL) private var openURL
    
    private var cardColor: Color {
        if let colors = collection.gradientColors, let first = colors.first {
            return Color(hex: first) ?? .purple
        }
        return .purple
    }
    
    @ViewBuilder
    private var collectionIcon: some View {
        // Если есть iconName - показываем картинку из Assets (без обводки)
        if let iconName = collection.iconName, !iconName.isEmpty,
           let image = UIImage(named: iconName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            // Градиентный фон + эмодзи (если нет картинки)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: collection.gradientColors?.compactMap { Color(hex: $0) } ?? [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Text(categoryIcon(for: collection.category))
                    .font(.title2)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок (всегда видна)
            Button(action: onToggleExpand) {
                HStack(spacing: 14) {
                    // Иконка категории (приоритет iconName > categoryIcon)
                    collectionIcon
                    
                    // Текст
                    VStack(alignment: .leading, spacing: 4) {
                        Text(collection.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        
                        if let subtitle = collection.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // Количество ресурсов + стрелка
                    HStack(spacing: 8) {
                        Text("\(collection.resources.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                            )
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            // Раскрытый контент со списком ресурсов
            if isExpanded {
                VStack(spacing: 0) {
                    // Разделитель
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    // Список ресурсов
                    VStack(spacing: 0) {
                        ForEach(Array(collection.resources.enumerated()), id: \.element.id) { index, resource in
                            ResourceRow(resource: resource, openURL: openURL)
                            
                            // Разделитель между ресурсами (кроме последнего)
                            if index < collection.resources.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 1)
                                    .padding(.leading, 60)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cardColor.opacity(0.2),
                            cardColor.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [cardColor.opacity(0.3), cardColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "security": return "🔐"
        case "programming": return "💻"
        case "law": return "⚖️"
        case "design": return "🎨"
        default: return "📚"
        }
    }
}

// MARK: - Resource Row (Строка ресурса в подборке)

private struct ResourceRow: View {
    let resource: Resource
    let openURL: OpenURLAction
    
    var body: some View {
        Button(action: {
            if let url = URL(string: resource.url) {
                openURL(url)
            }
        }) {
            HStack(spacing: 12) {
                // Иконка (приоритет iconName > icon)
                if let iconName = resource.iconName, !iconName.isEmpty,
                   let image = UIImage(named: iconName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Text(resource.icon ?? "🔗")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                
                // Информация
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(resource.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                        
                        if let subscribers = resource.subscribers, !subscribers.isEmpty {
                            Text(subscribers)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }
                    }
                    
                    if let description = resource.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Стрелка
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

