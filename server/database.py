import sqlite3
import json
import os
from datetime import datetime
from typing import List, Optional, Dict, Any

class AdminDatabase:
    def __init__(self, db_path: str = "admin.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Инициализация базы данных"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Таблица для рекламы
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS advertisements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                image_url TEXT,
                link_url TEXT,
                category TEXT DEFAULT 'course',
                is_active BOOLEAN DEFAULT 1,
                priority INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Таблица для новостей
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS news (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT,
                description TEXT,
                image_url TEXT NOT NULL,
                is_active BOOLEAN DEFAULT 1,
                priority INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Таблица для настроек приложения
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                setting_key TEXT UNIQUE NOT NULL,
                setting_value TEXT NOT NULL,
                description TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Таблица для push-уведомлений
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                is_sent BOOLEAN DEFAULT 0,
                scheduled_at TIMESTAMP,
                sent_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # Таблица для отслеживания версий контента
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS content_versions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content_type TEXT NOT NULL,
                version INTEGER NOT NULL,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.commit()
        conn.close()
        
        # Добавляем базовые настройки
        self.init_default_settings()
    
    def init_default_settings(self):
        """Добавление базовых настроек"""
        default_settings = [
            ("app_version", "1.0.0", "Версия приложения"),
            ("content_version", "1", "Версия контента"),
            ("update_check_interval", "3600", "Интервал проверки обновлений (секунды)"),
            ("maintenance_mode", "false", "Режим обслуживания"),
            ("featured_ad_duration", "5", "Длительность показа рекламы (секунды)"),
        ]
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        for key, value, description in default_settings:
            cursor.execute('''
                INSERT OR IGNORE INTO app_settings (setting_key, setting_value, description)
                VALUES (?, ?, ?)
            ''', (key, value, description))
        
        conn.commit()
        conn.close()
    
    # CRUD для рекламы
    def create_advertisement(self, title: str, description: str, image_url: str = None, 
                           link_url: str = None, category: str = "course") -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO advertisements (title, description, image_url, link_url, category)
            VALUES (?, ?, ?, ?, ?)
        ''', (title, description, image_url, link_url, category))
        ad_id = cursor.lastrowid
        conn.commit()
        conn.close()
        self.increment_content_version("advertisements")
        return ad_id
    
    def get_advertisements(self, active_only: bool = False) -> List[Dict]:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        query = "SELECT * FROM advertisements"
        if active_only:
            query += " WHERE is_active = 1"
        query += " ORDER BY priority DESC, created_at DESC"
        
        cursor.execute(query)
        ads = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return ads
    
    def update_advertisement(self, ad_id: int, **kwargs) -> bool:
        if not kwargs:
            return False
        
        # Добавляем updated_at
        kwargs['updated_at'] = datetime.now().isoformat()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        set_clause = ", ".join([f"{key} = ?" for key in kwargs.keys()])
        values = list(kwargs.values()) + [ad_id]
        
        cursor.execute(f'''
            UPDATE advertisements SET {set_clause} WHERE id = ?
        ''', values)
        
        success = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        if success:
            self.increment_content_version("advertisements")
        return success
    
    def delete_advertisement(self, ad_id: int) -> bool:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM advertisements WHERE id = ?", (ad_id,))
        success = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        if success:
            self.increment_content_version("advertisements")
        return success
    
    # CRUD для новостей
    def create_news(self, image_url: str, title: str = None, description: str = None) -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO news (title, description, image_url)
            VALUES (?, ?, ?)
        ''', (title, description, image_url))
        news_id = cursor.lastrowid
        conn.commit()
        conn.close()
        self.increment_content_version("news")
        return news_id
    
    def get_news(self, active_only: bool = False) -> List[Dict]:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        query = "SELECT * FROM news"
        if active_only:
            query += " WHERE is_active = 1"
        query += " ORDER BY priority DESC, created_at DESC"
        
        cursor.execute(query)
        news = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return news
    
    def update_news(self, news_id: int, **kwargs) -> bool:
        if not kwargs:
            return False
        
        kwargs['updated_at'] = datetime.now().isoformat()
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        set_clause = ", ".join([f"{key} = ?" for key in kwargs.keys()])
        values = list(kwargs.values()) + [news_id]
        
        cursor.execute(f'''
            UPDATE news SET {set_clause} WHERE id = ?
        ''', values)
        
        success = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        if success:
            self.increment_content_version("news")
        return success
    
    def delete_news(self, news_id: int) -> bool:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("DELETE FROM news WHERE id = ?", (news_id,))
        success = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        if success:
            self.increment_content_version("news")
        return success
    
    # Управление настройками
    def get_setting(self, key: str) -> Optional[str]:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT setting_value FROM app_settings WHERE setting_key = ?", (key,))
        result = cursor.fetchone()
        conn.close()
        return result[0] if result else None
    
    def set_setting(self, key: str, value: str, description: str = None) -> bool:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
            INSERT OR REPLACE INTO app_settings (setting_key, setting_value, description, updated_at)
            VALUES (?, ?, ?, ?)
        ''', (key, value, description, datetime.now().isoformat()))
        success = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return success
    
    def get_all_settings(self) -> Dict[str, Any]:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM app_settings ORDER BY setting_key")
        settings = {row['setting_key']: {
            'value': row['setting_value'],
            'description': row['description'],
            'updated_at': row['updated_at']
        } for row in cursor.fetchall()}
        conn.close()
        return settings
    
    # Управление версиями контента
    def increment_content_version(self, content_type: str):
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Получаем текущую версию
        cursor.execute("SELECT version FROM content_versions WHERE content_type = ?", (content_type,))
        result = cursor.fetchone()
        
        if result:
            new_version = result[0] + 1
            cursor.execute('''
                UPDATE content_versions SET version = ?, updated_at = ? 
                WHERE content_type = ?
            ''', (new_version, datetime.now().isoformat(), content_type))
        else:
            new_version = 1
            cursor.execute('''
                INSERT INTO content_versions (content_type, version)
                VALUES (?, ?)
            ''', (content_type, new_version))
        
        conn.commit()
        conn.close()
        
        # Обновляем общую версию контента
        self.set_setting("content_version", str(self.get_latest_content_version()))
    
    def get_content_version(self, content_type: str) -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT version FROM content_versions WHERE content_type = ?", (content_type,))
        result = cursor.fetchone()
        conn.close()
        return result[0] if result else 0
    
    def get_latest_content_version(self) -> int:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT MAX(version) FROM content_versions")
        result = cursor.fetchone()
        conn.close()
        return result[0] if result and result[0] else 1

# Глобальный экземпляр базы данных
db = AdminDatabase()
