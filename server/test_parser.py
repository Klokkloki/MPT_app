#!/usr/bin/env python3
import asyncio
from bs4 import BeautifulSoup
from parser import fetch_page, parse_specialties, parse_groups_for_specialty, parse_schedule_for_group, parse_week_info

async def main():
    print("Загрузка страницы...")
    html = await fetch_page()
    soup = BeautifulSoup(html, "lxml")
    
    # Проверяем week info
    week_info = parse_week_info(soup)
    print(f"\nНеделя: {week_info.week_type_ru} ({week_info.date})")
    
    # Получаем специальности
    specialties = parse_specialties(soup)
    print(f"\nНайдено {len(specialties)} специальностей:")
    for spec in specialties:
        print(f"  - {spec.name} (id: {spec.id[:20]}...)")
    
    # Берём первую специальность
    if specialties:
        spec = specialties[0]
        print(f"\n\nГруппы для {spec.name}:")
        groups = parse_groups_for_specialty(soup, spec.id)
        for g in groups:
            print(f"  - {g.name}")
        
        # Берём первую группу и смотрим расписание
        if groups:
            group = groups[0]
            print(f"\n\nРасписание для группы {group.name}:")
            
            # Найдём div специальности
            tab_content = soup.find("div", id=spec.id)
            if tab_content:
                print(f"  Найден div специальности: {spec.id}")
                
                # Ищем tab-pane с группой
                group_tabs = tab_content.find_all("div", class_="tab-pane")
                print(f"  Найдено {len(group_tabs)} tab-pane")
                
                for i, gt in enumerate(group_tabs):
                    h3 = gt.find("h3")
                    if h3:
                        print(f"    Tab {i}: {h3.get_text(strip=True)}")
                        tables = gt.find_all("table")
                        print(f"      Таблиц: {len(tables)}")
                        
                        for t in tables:
                            thead = t.find("thead")
                            if thead:
                                h4 = thead.find("h4")
                                if h4:
                                    print(f"        День: {h4.get_text(strip=True)}")
                            
                            # Ищем пары
                            for tbody in t.find_all("tbody"):
                                for row in tbody.find_all("tr"):
                                    cells = row.find_all("td")
                                    if len(cells) >= 3:
                                        num = cells[0].get_text(strip=True)
                                        subj = cells[1].get_text(strip=True)[:50]
                                        teach = cells[2].get_text(strip=True)[:30]
                                        if num.isdigit():
                                            print(f"          Пара {num}: {subj}... ({teach}...)")
            
            schedule = parse_schedule_for_group(soup, group.name, spec.id)
            if schedule:
                print(f"\n  Результат парсинга:")
                for day in schedule.days:
                    print(f"    {day.day}: {len(day.lessons)} пар, campus={day.campus}")
                    for lesson in day.lessons:
                        print(f"      - {lesson.number}: {lesson.subject[:40]}...")

if __name__ == "__main__":
    asyncio.run(main())

