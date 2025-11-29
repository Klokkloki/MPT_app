from pydantic import BaseModel
from typing import Optional
from enum import Enum


class WeekType(str, Enum):
    NUMERATOR = "numerator"      # Числитель
    DENOMINATOR = "denominator"  # Знаменатель


class WeekInfo(BaseModel):
    date: str                    # "27 Ноября - Четверг"
    week_type: WeekType          # numerator или denominator
    week_type_ru: str            # "Числитель" или "Знаменатель"


class Specialty(BaseModel):
    id: str                      # "09.02.01"
    code: str                    # "Э"
    name: str                    # "09.02.01 Э"
    full_name: Optional[str] = None  # Полное название если есть


class Group(BaseModel):
    id: str                      # "Э-1-22, Э-11/1-23"
    name: str                    # "Э-1-22, Э-11/1-23"
    specialty_id: str            # "09.02.01"


class Lesson(BaseModel):
    number: int                  # Номер пары (1-7)
    subject: str                 # Предмет
    teacher: str                 # Преподаватель
    subject_denominator: Optional[str] = None  # Предмет для знаменателя (если отличается)
    teacher_denominator: Optional[str] = None  # Преподаватель для знаменателя


class DaySchedule(BaseModel):
    day: str                     # "ПОНЕДЕЛЬНИК", "ВТОРНИК", и т.д.
    day_index: int               # 0-6 (пн-вс)
    campus: Optional[str] = None # "Нежинская", "Нахимовский", или None
    lessons: list[Lesson]        # Список пар
    is_day_off: bool = False     # Выходной ли день


class WeekSchedule(BaseModel):
    group: str                   # Название группы
    specialty_id: str            # ID специальности
    days: list[DaySchedule]      # Расписание на неделю (пн-сб)


class ScheduleResponse(BaseModel):
    week_info: WeekInfo
    schedule: WeekSchedule


# MARK: - Замены

class Replacement(BaseModel):
    pair_number: int              # Номер пары
    original_subject: str         # Что заменяют
    new_subject: str              # На что заменяют
    added_at: str                 # Когда добавлена замена


class GroupReplacements(BaseModel):
    group_name: str               # Название группы
    replacements: list[Replacement]


class DayReplacements(BaseModel):
    date: str                     # "28.11.2025"
    date_display: str             # "28 Ноября" или "Сегодня"
    is_today: bool                # Сегодняшний день?
    groups: list[GroupReplacements]


class ReplacementsResponse(BaseModel):
    days: list[DayReplacements]   # Замены по дням

