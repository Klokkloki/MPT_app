import httpx
from bs4 import BeautifulSoup
from typing import Optional
import re
from models import (
    WeekInfo, WeekType, Specialty, Group, 
    Lesson, DaySchedule, WeekSchedule
)


BASE_URL = "https://mpt.ru/raspisanie/"

# Маппинг дней недели
DAYS_MAP = {
    "ПОНЕДЕЛЬНИК": 0,
    "ВТОРНИК": 1,
    "СРЕДА": 2,
    "ЧЕТВЕРГ": 3,
    "ПЯТНИЦА": 4,
    "СУББОТА": 5,
    "ВОСКРЕСЕНЬЕ": 6
}

DAYS_NAMES = ["ПОНЕДЕЛЬНИК", "ВТОРНИК", "СРЕДА", "ЧЕТВЕРГ", "ПЯТНИЦА", "СУББОТА"]


async def fetch_page(url: str = BASE_URL) -> str:
    """Загружает HTML страницу"""
    async with httpx.AsyncClient() as client:
        response = await client.get(url, timeout=30.0)
        response.raise_for_status()
        return response.text


def parse_week_info(soup: BeautifulSoup) -> WeekInfo:
    """Парсит информацию о текущей неделе"""
    date_text = ""
    week_type = WeekType.NUMERATOR
    week_type_ru = "Числитель"
    
    # Ищем h2 с датой (формат: "27 Ноября - Четверг")
    h2_elements = soup.find_all("h2")
    for h2 in h2_elements:
        text = h2.get_text(strip=True)
        # Проверяем наличие месяца в тексте
        months = ["Января", "Февраля", "Марта", "Апреля", "Мая", "Июня", 
                  "Июля", "Августа", "Сентября", "Октября", "Ноября", "Декабря"]
        for month in months:
            if month in text:
                date_text = text
                break
        if date_text:
            break
    
    # Ищем h3 с типом недели
    h3_elements = soup.find_all("h3")
    for h3 in h3_elements:
        text = h3.get_text(strip=True)
        if "Неделя:" in text:
            if "Знаменатель" in text:
                week_type = WeekType.DENOMINATOR
                week_type_ru = "Знаменатель"
            else:
                week_type = WeekType.NUMERATOR
                week_type_ru = "Числитель"
            break
    
    return WeekInfo(
        date=date_text,
        week_type=week_type,
        week_type_ru=week_type_ru
    )


def parse_specialties(soup: BeautifulSoup) -> list[Specialty]:
    """Парсит список специальностей из табов и заголовков h2"""
    specialties = []
    found_ids = set()  # Чтобы избежать дубликатов по ID
    found_names = set()  # Чтобы избежать дубликатов по названию
    
    # Ищем ul.nav-tabs с табами специальностей (верхний уровень)
    nav_tabs = soup.find("ul", class_="nav-tabs")
    if nav_tabs:
        for li in nav_tabs.find_all("li"):
            a_tag = li.find("a")
            if a_tag:
                text = a_tag.get_text(strip=True)
                tab_id = a_tag.get("href", "").replace("#", "")
                
                if tab_id and tab_id not in found_ids and text not in found_names:
                    # Парсим код и название специальности
                    # Формат: "09.02.01 Э" или "09.02.07 ИС, БД, ВД"
                    match = re.match(r'^([\d.,\s]+)\s+(.+)$', text)
                    if match:
                        code = match.group(2).strip()
                    else:
                        # Если не подходит под формат, используем весь текст как код
                        code = text
                    
                    specialties.append(Specialty(
                        id=tab_id,
                        code=code,
                        name=text,
                        full_name=None
                    ))
                    found_ids.add(tab_id)
                    found_names.add(text)
    
    # Также ищем специальности в заголовках h2 (например, "Отделение первого курса")
    # которые не попали в основной список табов
    h2_headers = soup.find_all("h2")
    for h2 in h2_headers:
        text = h2.get_text(strip=True)
        # Ищем заголовки вида "Расписание занятий для Отделение первого курса"
        if "Расписание занятий для" in text:
            specialty_name = text.replace("Расписание занятий для", "").strip()
            
            # Пропускаем если уже есть в списке
            if specialty_name in found_names:
                continue
            
            # Ищем следующий ul.nav-tabs после этого h2 для получения tab_id
            next_tabs = h2.find_next("ul", class_="nav-tabs")
            if next_tabs:
                first_tab = next_tabs.find("li")
                if first_tab:
                    a_tag = first_tab.find("a")
                    if a_tag:
                        tab_id = a_tag.get("href", "").replace("#", "")
                        if tab_id and tab_id not in found_ids:
                            # Для "Отделение первого курса" используем название как код
                            code = specialty_name if specialty_name else "ОПК"
                            
                            specialties.append(Specialty(
                                id=tab_id,
                                code=code,
                                name=specialty_name,
                                full_name=None
                            ))
                            found_ids.add(tab_id)
                            found_names.add(specialty_name)
    
    return specialties


def parse_groups_for_specialty(soup: BeautifulSoup, specialty_tab_id: str) -> list[Group]:
    """Парсит группы для конкретной специальности по ID таба"""
    groups = []
    
    # Находим div с контентом специальности
    tab_content = soup.find("div", id=specialty_tab_id)
    if not tab_content:
        return groups
    
    # Внутри специальности есть вложенные табы для групп
    # Ищем все tab-pane внутри специальности
    group_tabs = tab_content.find_all("div", class_="tab-pane")
    
    for group_tab in group_tabs:
        # Ищем h3 с названием группы
        h3 = group_tab.find("h3")
        if h3:
            text = h3.get_text(strip=True)
            if text.startswith("Группа "):
                group_name = text.replace("Группа ", "").strip()
                groups.append(Group(
                    id=group_name,
                    name=group_name,
                    specialty_id=specialty_tab_id
                ))
    
    # Если вложенных табов нет, ищем h3 напрямую
    if not groups:
        h3_elements = tab_content.find_all("h3")
        for h3 in h3_elements:
            text = h3.get_text(strip=True)
            if text.startswith("Группа "):
                group_name = text.replace("Группа ", "").strip()
                groups.append(Group(
                    id=group_name,
                    name=group_name,
                    specialty_id=specialty_tab_id
                ))
    
    return groups


def parse_schedule_for_group(soup: BeautifulSoup, group_name: str, specialty_tab_id: str) -> Optional[WeekSchedule]:
    """Парсит расписание для конкретной группы"""
    
    # Находим div с контентом специальности
    tab_content = soup.find("div", id=specialty_tab_id)
    if not tab_content:
        return None
    
    # Ищем tab-pane с нужной группой
    group_pane = None
    group_tabs = tab_content.find_all("div", class_="tab-pane")
    
    for group_tab in group_tabs:
        h3 = group_tab.find("h3")
        if h3:
            text = h3.get_text(strip=True)
            if f"Группа {group_name}" == text:
                group_pane = group_tab
                break
    
    if not group_pane:
        # Если tab-pane не найден, пробуем искать h3 напрямую
        h3_elements = tab_content.find_all("h3")
        for h3 in h3_elements:
            text = h3.get_text(strip=True)
            if f"Группа {group_name}" == text:
                # Берём родительский контейнер
                group_pane = h3.parent
                break
    
    if not group_pane:
        return None
    
    # Собираем все таблицы в этом tab-pane
    days_schedule = []
    tables = group_pane.find_all("table")
    
    for table in tables:
        day_schedule = parse_day_table(table)
        if day_schedule:
            days_schedule.append(day_schedule)
    
    # Сортируем по индексу дня
    days_schedule.sort(key=lambda x: x.day_index)
    
    # Добавляем выходные дни (те, которых нет в расписании)
    existing_days = {d.day_index for d in days_schedule}
    for i, day_name in enumerate(DAYS_NAMES):
        if i not in existing_days:
            days_schedule.append(DaySchedule(
                day=day_name,
                day_index=i,
                campus=None,
                lessons=[],
                is_day_off=True
            ))
    
    # Пересортируем
    days_schedule.sort(key=lambda x: x.day_index)
    
    return WeekSchedule(
        group=group_name,
        specialty_id=specialty_tab_id,
        days=days_schedule
    )


def parse_day_table(table) -> Optional[DaySchedule]:
    """Парсит таблицу расписания на один день"""
    
    # Ищем заголовок с днём недели в thead
    thead = table.find("thead")
    if not thead:
        return None
    
    h4 = thead.find("h4")
    if not h4:
        return None
    
    header_text = h4.get_text(strip=True)
    
    # Извлекаем день и территорию
    day_name = None
    campus = None
    
    for day in DAYS_MAP.keys():
        if day in header_text.upper():
            day_name = day
            # Территория в span
            span = h4.find("span")
            if span:
                campus = span.get_text(strip=True)
                if not campus:
                    campus = None
            break
    
    if not day_name:
        return None
    
    # Парсим пары из всех tbody
    lessons = []
    tbody_list = table.find_all("tbody")
    
    for tbody in tbody_list:
        rows = tbody.find_all("tr")
        for row in rows:
            cells = row.find_all("td")
            if len(cells) >= 3:
                try:
                    number_text = cells[0].get_text(strip=True)
                    if not number_text.isdigit():
                        continue
                    number = int(number_text)
                    
                    # Проверяем на сдвоенную пару (числитель/знаменатель)
                    subject_cell = cells[1]
                    teacher_cell = cells[2]
                    
                    # Ищем label-danger (числитель) и label-info (знаменатель)
                    numerator_div = subject_cell.find("div", class_="label-danger")
                    denominator_div = subject_cell.find("div", class_="label-info")
                    
                    if numerator_div or denominator_div:
                        # Сдвоенная пара
                        subject_num = numerator_div.get_text(strip=True) if numerator_div else ""
                        subject_den = denominator_div.get_text(strip=True) if denominator_div else ""
                        
                        # Преподаватели тоже могут быть разные
                        teacher_num_div = teacher_cell.find("div", class_="label-danger")
                        teacher_den_div = teacher_cell.find("div", class_="label-info")
                        
                        if teacher_num_div or teacher_den_div:
                            teacher_num = teacher_num_div.get_text(strip=True) if teacher_num_div else ""
                            teacher_den = teacher_den_div.get_text(strip=True) if teacher_den_div else ""
                        else:
                            # Один преподаватель на обе недели
                            teacher_num = teacher_cell.get_text(strip=True)
                            teacher_den = teacher_num
                        
                        lesson = Lesson(
                            number=number,
                            subject=subject_num if subject_num else subject_den,
                            teacher=teacher_num if teacher_num else teacher_den,
                            subject_denominator=subject_den if subject_den and subject_den != subject_num else None,
                            teacher_denominator=teacher_den if teacher_den and teacher_den != teacher_num else None
                        )
                    else:
                        # Обычная пара
                        subject = subject_cell.get_text(strip=True)
                        teacher = teacher_cell.get_text(strip=True)
                        
                        lesson = Lesson(
                            number=number,
                            subject=subject,
                            teacher=teacher
                        )
                    
                    if lesson.number > 0 and lesson.subject:
                        lessons.append(lesson)
                        
                except (ValueError, IndexError) as e:
                    continue
    
    return DaySchedule(
        day=day_name,
        day_index=DAYS_MAP.get(day_name, 0),
        campus=campus,
        lessons=lessons,
        is_day_off=len(lessons) == 0
    )


async def get_all_data():
    """Получает все данные с сайта"""
    html = await fetch_page()
    soup = BeautifulSoup(html, "lxml")
    
    week_info = parse_week_info(soup)
    specialties = parse_specialties(soup)
    
    return {
        "week_info": week_info,
        "specialties": specialties,
        "soup": soup
    }


def get_all_groups_from_soup(soup: BeautifulSoup, specialties: list[Specialty]) -> dict:
    """Получает все группы для всех специальностей"""
    result = {}
    for spec in specialties:
        groups = parse_groups_for_specialty(soup, spec.id)
        result[spec.name] = groups
    return result


# MARK: - Парсинг замен

REPLACEMENTS_URL = "https://mpt.ru/izmeneniya-v-raspisanii/"

from models import Replacement, GroupReplacements, DayReplacements, ReplacementsResponse
from datetime import datetime


async def fetch_replacements() -> ReplacementsResponse:
    """Загружает и парсит страницу замен"""
    html = await fetch_page(REPLACEMENTS_URL)
    soup = BeautifulSoup(html, "lxml")
    return parse_replacements(soup)


def parse_replacements(soup: BeautifulSoup) -> ReplacementsResponse:
    """Парсит замены со страницы"""
    days = []
    
    # Находим все заголовки h4 с датами замен
    h4_headers = soup.find_all("h4")
    
    for h4 in h4_headers:
        text = h4.get_text(strip=True)
        
        # Ищем заголовки вида "Замены на 28.11.2025 (Сегодня)"
        if "Замены на" not in text:
            continue
        
        # Извлекаем дату
        date_match = re.search(r'(\d{2}\.\d{2}\.\d{4})', text)
        if not date_match:
            continue
        
        date_str = date_match.group(1)
        is_today = "Сегодня" in text
        
        # Форматируем дату для отображения
        try:
            date_obj = datetime.strptime(date_str, "%d.%m.%Y")
            months_ru = {
                1: "Января", 2: "Февраля", 3: "Марта", 4: "Апреля",
                5: "Мая", 6: "Июня", 7: "Июля", 8: "Августа",
                9: "Сентября", 10: "Октября", 11: "Ноября", 12: "Декабря"
            }
            date_display = f"{date_obj.day} {months_ru[date_obj.month]}"
        except:
            date_display = date_str
        
        # Ищем все таблицы после этого заголовка до следующего h4 или hr
        groups = []
        current = h4.find_next_sibling()
        
        while current:
            # Останавливаемся на следующем h4 или hr
            if current.name == "h4":
                break
            if current.name == "hr":
                break
            
            # Ищем таблицы с caption (название группы в caption)
            if current.name == "div" and "table-responsive" in current.get("class", []):
                table = current.find("table")
                if table:
                    # Название группы в caption
                    caption = table.find("caption")
                    if caption:
                        # Извлекаем название группы из "Группа: <b>Ю-1-23</b>"
                        group_text = caption.get_text(strip=True)
                        group_name = group_text.replace("Группа:", "").strip()
                        
                        replacements = parse_replacement_table(table)
                        if replacements:
                            groups.append(GroupReplacements(
                                group_name=group_name,
                                replacements=replacements
                            ))
            
            current = current.find_next_sibling()
        
        if groups:
            days.append(DayReplacements(
                date=date_str,
                date_display=date_display,
                is_today=is_today,
                groups=groups
            ))
    
    return ReplacementsResponse(days=days)


def parse_replacement_table(table) -> list[Replacement]:
    """Парсит таблицу замен для одной группы"""
    replacements = []
    
    rows = table.find_all("tr")
    for row in rows[1:]:  # Пропускаем заголовок
        cells = row.find_all("td")
        if len(cells) >= 4:
            try:
                pair_number = int(cells[0].get_text(strip=True))
                original = cells[1].get_text(strip=True)
                new_subject = cells[2].get_text(strip=True)
                added_at = cells[3].get_text(strip=True)
                
                replacements.append(Replacement(
                    pair_number=pair_number,
                    original_subject=original,
                    new_subject=new_subject,
                    added_at=added_at
                ))
            except (ValueError, IndexError):
                continue
    
    return replacements


def get_replacements_for_group(replacements: ReplacementsResponse, group_name: str) -> ReplacementsResponse:
    """Фильтрует замены только для конкретной группы"""
    filtered_days = []
    
    for day in replacements.days:
        # Ищем группу (учитываем что название может быть частью)
        matching_groups = []
        for group in day.groups:
            # Проверяем совпадение (группа может быть "Э-1-22, Э-11/1-23")
            if group_name in group.group_name or group.group_name in group_name:
                matching_groups.append(group)
        
        if matching_groups:
            filtered_days.append(DayReplacements(
                date=day.date,
                date_display=day.date_display,
                is_today=day.is_today,
                groups=matching_groups
            ))
    
    return ReplacementsResponse(days=filtered_days)
