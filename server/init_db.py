from database import db

# Скрипт для инициализации базы данных с тестовыми данными

def init_test_data():
    """Добавляем тестовые данные в базу"""
    
    # Добавляем тестовую рекламу
    test_ads = [
        {
            "title": "Skillbox — IT курсы",
            "description": "Получи востребованную профессию в IT. Скидка для студентов 20%",
            "link_url": "https://skillbox.ru",
            "category": "onlineSchool"
        },
        {
            "title": "GeekBrains — Программирование", 
            "description": "Изучай Python, Java, JavaScript с нуля. Практика + трудоустройство",
            "link_url": "https://gb.ru",
            "category": "course"
        },
        {
            "title": "Яндекс.Практикум",
            "description": "Онлайн-курсы по Data Science, дизайну, маркетингу. Бесплатная часть",
            "link_url": "https://practicum.yandex.ru", 
            "category": "course"
        }
    ]
    
    for ad in test_ads:
        db.create_advertisement(**ad)
    
    # Добавляем тестовые новости
    test_news = [
        {
            "image_url": "00.10.2024",
            "title": "Экскурсия",
            "description": "Студенты МПТ на экскурсии"
        },
        {
            "image_url": "head", 
            "title": "Новости колледжа",
            "description": "Следите за событиями"
        },
        {
            "image_url": "prevyu-studenty-mpt-na-obshherossijskom-turnire-po-robototehnike-24-26.09.2025",
            "title": "Робототехника", 
            "description": "Студенты МПТ на всероссийском турнире"
        }
    ]
    
    for news in test_news:
        db.create_news(**news)
    
    print("✅ Тестовые данные добавлены в базу")
    print(f"📊 Реклам: {len(db.get_advertisements())}")
    print(f"📰 Новостей: {len(db.get_news())}")

if __name__ == "__main__":
    init_test_data()
