# MPT Schedule Server

Python-сервер для парсинга расписания с сайта МПТ (mpt.ru) и предоставления API для iOS-приложения.

## Установка

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Запуск

```bash
source venv/bin/activate
python main.py
```

Сервер запустится на `http://localhost:8000`

## API Endpoints

### GET /api/week-info
Информация о текущей неделе (Числитель/Знаменатель)

```json
{
  "date": "27 Ноября - Четверг",
  "week_type": "numerator",
  "week_type_ru": "Числитель"
}
```

### GET /api/specialties
Список всех специальностей

```json
[
  {
    "id": "69d898df1add22061438dbc8ff0a73fa",
    "code": "Э",
    "name": "09.02.01 Э"
  }
]
```

### GET /api/groups?specialty_id=<id>
Группы для специальности

### GET /api/schedule?group=<name>&specialty_id=<id>
Расписание группы на неделю

Пример: `/api/schedule?group=Э-1-22, Э-11/1-23&specialty_id=69d898df1add22061438dbc8ff0a73fa`

### GET /api/refresh
Принудительное обновление кеша

## Структура проекта

- `main.py` - FastAPI приложение
- `parser.py` - Парсер HTML с mpt.ru
- `models.py` - Pydantic модели данных
- `requirements.txt` - Зависимости

## Особенности парсинга

- Поддержка сдвоенных пар (Числитель/Знаменатель)
- Автоматическое определение территории (Нежинская/Нахимовский)
- Кеширование данных на 5 минут

