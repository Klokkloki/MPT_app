from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
import time
from bs4 import BeautifulSoup

from models import (
    WeekInfo, Specialty, Group, WeekSchedule, ScheduleResponse,
    ReplacementsResponse
)
from parser import (
    fetch_page, parse_week_info, parse_specialties,
    parse_groups_for_specialty, parse_schedule_for_group,
    get_all_groups_from_soup, fetch_replacements, get_replacements_for_group
)


app = FastAPI(
    title="MPT Schedule API",
    description="API для получения расписания Московского приборостроительного техникума",
    version="1.0.0"
)

# CORS для iOS приложения
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Кеш для данных (простой in-memory кеш)
cache = {
    "html": None,
    "soup": None,
    "week_info": None,
    "specialties": None,
    "last_update": None
}


async def get_soup() -> BeautifulSoup:
    """Получает и кеширует BeautifulSoup объект"""
    current_time = time.time()
    
    # Обновляем кеш каждые 5 минут
    if cache["soup"] is None or cache["last_update"] is None or \
       (current_time - cache["last_update"]) > 300:
        print("Загрузка страницы с сайта...")
        html = await fetch_page()
        cache["html"] = html
        cache["soup"] = BeautifulSoup(html, "lxml")
        cache["last_update"] = current_time
        cache["week_info"] = None
        cache["specialties"] = None
        print("Страница загружена и закеширована")
    
    return cache["soup"]


@app.get("/")
async def root():
    """Корневой endpoint"""
    return {
        "message": "MPT Schedule API",
        "version": "1.0.0",
        "endpoints": {
            "week_info": "/api/week-info",
            "specialties": "/api/specialties",
            "groups": "/api/groups?specialty_id=<tab_id>",
            "schedule": "/api/schedule?group=<group_name>&specialty_id=<tab_id>",
            "all_groups": "/api/all-groups",
            "content": {
                "advertisements": "/api/content/advertisements",
                "news": "/api/content/news",
                "app_info": "/api/content/app-info"
            },
            "admin": "/admin"
        }
    }


@app.get("/api/week-info", response_model=WeekInfo)
async def get_week_info():
    """Получить информацию о текущей неделе (дата и тип: Числитель/Знаменатель)"""
    try:
        soup = await get_soup()
        
        if cache["week_info"] is None:
            cache["week_info"] = parse_week_info(soup)
        
        return cache["week_info"]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка парсинга: {str(e)}")


@app.get("/api/specialties", response_model=list[Specialty])
async def get_specialties():
    """Получить список специальностей"""
    try:
        soup = await get_soup()
        
        if cache["specialties"] is None:
            cache["specialties"] = parse_specialties(soup)
        
        return cache["specialties"]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка парсинга: {str(e)}")


@app.get("/api/groups", response_model=list[Group])
async def get_groups(specialty_id: str = Query(..., description="ID специальности (tab_id из /api/specialties)")):
    """Получить группы для специальности"""
    try:
        soup = await get_soup()
        groups = parse_groups_for_specialty(soup, specialty_id)
        
        if not groups:
            raise HTTPException(status_code=404, detail=f"Группы для специальности '{specialty_id}' не найдены")
        
        return groups
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка парсинга: {str(e)}")


@app.get("/api/schedule")
async def get_schedule(
    group: str = Query(..., description="Название группы, например 'Э-1-22, Э-11/1-23'"),
    specialty_id: str = Query(..., description="ID специальности (tab_id)")
):
    """Получить расписание для группы на неделю"""
    try:
        soup = await get_soup()
        
        week_info = parse_week_info(soup)
        print(f"Парсинг расписания для группы: {group}, specialty_id: {specialty_id}")
        schedule = parse_schedule_for_group(soup, group, specialty_id)
        
        if not schedule:
            print(f"Расписание не найдено для группы: {group}")
            raise HTTPException(status_code=404, detail=f"Расписание для группы '{group}' не найдено")
        
        # Подсчитываем количество пар
        total_lessons = sum(len(day.lessons) for day in schedule.days)
        print(f"Найдено {total_lessons} пар в расписании")
        
        # Преобразуем в dict для отладки
        result = {
            "week_info": {
                "date": week_info.date,
                "week_type": week_info.week_type.value,
                "week_type_ru": week_info.week_type_ru
            },
            "schedule": {
                "group": schedule.group,
                "specialty_id": schedule.specialty_id,
                "days": [
                    {
                        "day": day.day,
                        "day_index": day.day_index,
                        "campus": day.campus,
                        "lessons": [
                            {
                                "number": lesson.number,
                                "subject": lesson.subject,
                                "teacher": lesson.teacher,
                                "subject_denominator": lesson.subject_denominator,
                                "teacher_denominator": lesson.teacher_denominator
                            }
                            for lesson in day.lessons
                        ],
                        "is_day_off": day.is_day_off
                    }
                    for day in schedule.days
                ]
            }
        }
        
        return result
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка парсинга: {str(e)}")


@app.get("/api/all-groups")
async def get_all_groups():
    """Получить все группы для всех специальностей"""
    try:
        soup = await get_soup()
        specialties = parse_specialties(soup)
        
        result = {}
        for spec in specialties:
            groups = parse_groups_for_specialty(soup, spec.id)
            result[spec.name] = {
                "specialty_id": spec.id,
                "code": spec.code,
                "groups": [{"id": g.id, "name": g.name} for g in groups]
            }
        
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ошибка парсинга: {str(e)}")


@app.get("/api/refresh")
async def refresh_cache():
    """Принудительно обновить кеш"""
    cache["soup"] = None
    cache["html"] = None
    cache["week_info"] = None
    cache["specialties"] = None
    cache["last_update"] = None
    cache["replacements"] = None
    cache["replacements_update"] = None
    
    await get_soup()
    
    return {"message": "Кеш обновлён", "timestamp": time.time()}


# MARK: - Замены

@app.get("/api/replacements")
async def get_replacements(
    group: Optional[str] = Query(None, description="Название группы для фильтрации (опционально)")
):
    """Получить замены в расписании. Если указана группа — только для неё."""
    try:
        current_time = time.time()
        
        # Кешируем замены на 2 минуты (они обновляются чаще)
        if cache.get("replacements") is None or cache.get("replacements_update") is None or \
           (current_time - cache.get("replacements_update", 0)) > 120:
            print("Загрузка страницы замен...")
            cache["replacements"] = await fetch_replacements()
            cache["replacements_update"] = current_time
            print(f"Загружено {sum(len(d.groups) for d in cache['replacements'].days)} групп с заменами")
        
        replacements = cache["replacements"]
        
        # Фильтруем по группе если указана
        if group:
            replacements = get_replacements_for_group(replacements, group)
        
        return replacements
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка парсинга замен: {str(e)}")


# MARK: - Все преподаватели

@app.get("/api/teachers")
async def get_all_teachers():
    """Получить список всех преподавателей из всех групп (без повторений)"""
    try:
        soup = await get_soup()
        specialties = parse_specialties(soup)
        
        all_teachers = set()
        
        for spec in specialties:
            groups = parse_groups_for_specialty(soup, spec.id)
            
            for group in groups:
                try:
                    schedule = parse_schedule_for_group(soup, group.name, spec.id)
                    if schedule:
                        for day in schedule.days:
                            for lesson in day.lessons:
                                # Разделяем по запятым и добавляем
                                if lesson.teacher:
                                    for teacher in lesson.teacher.split(","):
                                        name = teacher.strip()
                                        if name and len(name) > 2:
                                            all_teachers.add(name)
                                if lesson.teacher_denominator:
                                    for teacher in lesson.teacher_denominator.split(","):
                                        name = teacher.strip()
                                        if name and len(name) > 2:
                                            all_teachers.add(name)
                except Exception as e:
                    print(f"Ошибка при парсинге группы {group.name}: {e}")
                    continue
        
        # Сортируем по алфавиту
        sorted_teachers = sorted(list(all_teachers))
        
        return {
            "count": len(sorted_teachers),
            "teachers": sorted_teachers
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Ошибка получения преподавателей: {str(e)}")


# MARK: - Content API (Статичный контент, обновляемый через код)
#
# 🚀 БЫСТРОЕ ОБНОВЛЕНИЕ КОНТЕНТА:
# 1. Измени рекламу/новости ниже
# 2. Увеличь CONTENT_VERSION (например: "1.0" → "1.1")
# 3. Git push → Render redeploy
# 4. Пользователи получат обновления через 5 минут автоматически!
#
# ⚡ Пользователи проверяют обновления:
#   - При открытии приложения
#   - При открытии вкладки "Новости"  
#   - Автоматически каждые 5 минут в фоне

# Версия контента (ОБЯЗАТЕЛЬНО увеличивайте при любом изменении!)
CONTENT_VERSION = "2.0"

@app.get("/api/content/advertisements")
async def get_content_advertisements():
    """
    Получить рекомендации для мобильного приложения
    
    Поля:
    - id: уникальный идентификатор
    - title: заголовок (обязательно)
    - subtitle: короткое описание для свёрнутой карточки (опционально)
    - description: полное описание для раскрытой карточки (обязательно)
    - iconName: имя иконки в Assets (опционально)
    - iconEmoji: эмодзи как иконка (опционально)
    - iconUrl: URL иконки с сервера (опционально, пока не реализовано)
    - url: ссылка для перехода (опционально)
    - category: course | onlineSchool | telegram | youtube | service | event
    - tags: массив тегов ["бесплатно", "скидка", "новое", "топ"] (опционально)
    - gradientColors: массив HEX цветов для градиента ["#FF6B6B", "#4ECDC4"] (опционально)
    - isPinned: закреплённая реклама показывается первой (опционально)
    """
    
    # ИЗМЕНЯЙТЕ ЭТОТ СПИСОК ДЛЯ ОБНОВЛЕНИЯ РЕКОМЕНДАЦИЙ
    advertisements = [
        # === TELEGRAM КАНАЛЫ ===
        {
            "id": "tg-1",
            "title": "МПТ Мемы",
            "subtitle": "Лучшие мемы про колледж",
            "description": "Официальный канал с мемами про жизнь в МПТ. Подписывайся, чтобы не пропустить самое смешное! Публикуем мемы про пары, преподов и студенческую жизнь.",
            "iconEmoji": "😂",
            "url": "https://t.me/mpt_memes",
            "category": "telegram",
            "tags": ["новое"],
            "gradientColors": ["#0088cc", "#00aced"],
            "isPinned": True
        },
        {
            "id": "tg-2", 
            "title": "IT Новости",
            "subtitle": "Технологии и программирование",
            "description": "Канал с актуальными новостями из мира IT. Обзоры технологий, советы по программированию, карьерные возможности для студентов.",
            "iconEmoji": "💻",
            "url": "https://t.me/it_news_channel",
            "category": "telegram",
            "gradientColors": ["#667eea", "#764ba2"]
        },
        
        # === ОНЛАЙН-ШКОЛЫ ===
        {
            "id": "school-1",
            "title": "Яндекс.Практикум",
            "subtitle": "Бесплатные курсы для старта",
            "description": "Онлайн-курсы по Data Science, веб-разработке, дизайну и маркетингу. Первые уроки бесплатно — попробуй и реши, подходит ли тебе профессия.",
            "iconEmoji": "🎓",
            "url": "https://practicum.yandex.ru",
            "category": "onlineSchool",
            "tags": ["бесплатно"],
            "gradientColors": ["#FF0000", "#FF6B6B"]
        },
        {
            "id": "school-2",
            "title": "Stepik",
            "subtitle": "Бесплатные курсы от университетов",
            "description": "Тысячи бесплатных курсов по программированию, математике, физике и другим наукам. Сертификаты о прохождении. Идеально для самообучения!",
            "iconEmoji": "📚",
            "url": "https://stepik.org",
            "category": "course",
            "tags": ["бесплатно", "топ"],
            "gradientColors": ["#00C853", "#69F0AE"]
        },
        
        # === YOUTUBE КАНАЛЫ ===
        {
            "id": "yt-1",
            "title": "Хауди Хо",
            "subtitle": "Программирование простым языком",
            "description": "Один из лучших YouTube-каналов о программировании на русском языке. Туториалы по Python, JavaScript, веб-разработке. Подходит для начинающих!",
            "iconEmoji": "🎬",
            "url": "https://youtube.com/@HowdyHo",
            "category": "youtube",
            "tags": ["топ"],
            "gradientColors": ["#FF0000", "#CC0000"]
        },
        {
            "id": "yt-2",
            "title": "Winderton",
            "subtitle": "Мотивация и саморазвитие в IT",
            "description": "Канал о том, как стать успешным разработчиком. Советы по карьере, мотивация, истории успеха. Для тех, кто хочет расти в IT.",
            "iconEmoji": "🚀",
            "url": "https://youtube.com/@winderton",
            "category": "youtube",
            "gradientColors": ["#9C27B0", "#E040FB"]
        },
        
        # === КУРСЫ ===
        {
            "id": "course-1",
            "title": "HTML Academy",
            "subtitle": "Интерактивное обучение веб-разработке",
            "description": "Лучшие интерактивные курсы по HTML, CSS и JavaScript. Учись на практике — пиши код прямо в браузере. Есть бесплатные курсы для старта.",
            "iconEmoji": "🌐",
            "url": "https://htmlacademy.ru",
            "category": "course",
            "tags": ["бесплатно"],
            "gradientColors": ["#FF6B35", "#F7C59F"]
        },
        {
            "id": "course-2",
            "title": "CS50 на русском",
            "subtitle": "Легендарный курс Гарварда",
            "description": "Знаменитый курс по основам программирования от Гарварда, переведённый на русский. Бесплатно, качественно, для всех уровней.",
            "iconEmoji": "🏛️",
            "url": "https://javarush.com/quests/lectures/questharvard.level00.lecture00",
            "category": "course",
            "tags": ["бесплатно", "топ"],
            "gradientColors": ["#1E3A8A", "#3B82F6"]
        },
        
        # === СЕРВИСЫ ===
        {
            "id": "service-1",
            "title": "GitHub Student Pack",
            "subtitle": "Бесплатные инструменты для студентов",
            "description": "Огромный набор бесплатных инструментов для студентов: домены, хостинг, IDE, курсы и многое другое. Нужна только студенческая почта!",
            "iconEmoji": "🎁",
            "url": "https://education.github.com/pack",
            "category": "service",
            "tags": ["бесплатно", "топ"],
            "gradientColors": ["#24292e", "#6e7681"],
            "isPinned": True
        }
    ]
    
    return {"advertisements": advertisements}

@app.get("/api/content/news") 
async def get_content_news():
    """Получить новости для мобильного приложения"""
    # ИЗМЕНЯЙТЕ ЭТОТ СПИСОК ДЛЯ ОБНОВЛЕНИЯ НОВОСТЕЙ
    news = [
        {
            "id": "1",
            "imageName": "news_0",
            "title": "Экскурсия",
            "description": "Студенты МПТ на экскурсии"
        },
        {
            "id": "2", 
            "imageName": "news_1",  # Имя файла БЕЗ расширения (файл должен быть в папке news/ проекта)
            "title": "Новости колледжа",
            "description": "Следите за событиями"
        },
        {
            "id": "3",
            "imageName": "news_4",
            "title": "Робототехника",
            "description": "Студенты МПТ на всероссийском турнире" 
        }
    ]
    
    return {"news": news}

@app.get("/api/content/version")
async def get_content_version():
    """Проверка версии контента"""
    return {
        "version": CONTENT_VERSION,
        "timestamp": "2024-11-29T10:00:00Z"
    }


if __name__ == "__main__":
    import uvicorn
    import os
    # Render автоматически устанавливает переменную PORT
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
