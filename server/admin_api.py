from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Depends
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from typing import Optional, List
import secrets
import shutil
import os
from datetime import datetime
from database import db
from pydantic import BaseModel

# Создаем роутер для админки
admin_router = APIRouter(prefix="/admin", tags=["admin"])

# Простая HTTP Basic аутентификация
security = HTTPBasic()

# Учетные данные админа (в продакшене использовать переменные окружения)
ADMIN_USERNAME = "admin"
ADMIN_PASSWORD = "mpt2024!"  # ИЗМЕНИТЕ НА БОЛЕЕ БЕЗОПАСНЫЙ!

def get_current_admin(credentials: HTTPBasicCredentials = Depends(security)):
    """Проверка аутентификации админа"""
    correct_username = secrets.compare_digest(credentials.username, ADMIN_USERNAME)
    correct_password = secrets.compare_digest(credentials.password, ADMIN_PASSWORD)
    
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=401,
            detail="Неверные учетные данные",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username

# Pydantic модели для админки
class AdvertisementCreate(BaseModel):
    title: str
    description: str
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    category: str = "course"

class AdvertisementUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    link_url: Optional[str] = None
    category: Optional[str] = None
    is_active: Optional[bool] = None
    priority: Optional[int] = None

class NewsCreate(BaseModel):
    image_url: str
    title: Optional[str] = None
    description: Optional[str] = None

class NewsUpdate(BaseModel):
    image_url: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None
    priority: Optional[int] = None

class AppSetting(BaseModel):
    key: str
    value: str
    description: Optional[str] = None

# HTML-интерфейс админки
@admin_router.get("/", response_class=HTMLResponse)
async def admin_dashboard(admin: str = Depends(get_current_admin)):
    """Главная страница админки"""
    return get_admin_html()

# API для рекламы
@admin_router.get("/api/advertisements")
async def get_advertisements_api(admin: str = Depends(get_current_admin)):
    """Получить все рекламы"""
    return {"advertisements": db.get_advertisements()}

@admin_router.post("/api/advertisements")
async def create_advertisement_api(ad: AdvertisementCreate, admin: str = Depends(get_current_admin)):
    """Создать новую рекламу"""
    ad_id = db.create_advertisement(**ad.dict())
    return {"message": "Реклама создана", "id": ad_id}

@admin_router.put("/api/advertisements/{ad_id}")
async def update_advertisement_api(ad_id: int, ad: AdvertisementUpdate, admin: str = Depends(get_current_admin)):
    """Обновить рекламу"""
    success = db.update_advertisement(ad_id, **{k: v for k, v in ad.dict().items() if v is not None})
    if not success:
        raise HTTPException(status_code=404, detail="Реклама не найдена")
    return {"message": "Реклама обновлена"}

@admin_router.delete("/api/advertisements/{ad_id}")
async def delete_advertisement_api(ad_id: int, admin: str = Depends(get_current_admin)):
    """Удалить рекламу"""
    success = db.delete_advertisement(ad_id)
    if not success:
        raise HTTPException(status_code=404, detail="Реклама не найдена")
    return {"message": "Реклама удалена"}

# API для новостей
@admin_router.get("/api/news")
async def get_news_api(admin: str = Depends(get_current_admin)):
    """Получить все новости"""
    return {"news": db.get_news()}

@admin_router.post("/api/news")
async def create_news_api(news: NewsCreate, admin: str = Depends(get_current_admin)):
    """Создать новость"""
    news_id = db.create_news(**news.dict())
    return {"message": "Новость создана", "id": news_id}

@admin_router.put("/api/news/{news_id}")
async def update_news_api(news_id: int, news: NewsUpdate, admin: str = Depends(get_current_admin)):
    """Обновить новость"""
    success = db.update_news(news_id, **{k: v for k, v in news.dict().items() if v is not None})
    if not success:
        raise HTTPException(status_code=404, detail="Новость не найдена")
    return {"message": "Новость обновлена"}

@admin_router.delete("/api/news/{news_id}")
async def delete_news_api(news_id: int, admin: str = Depends(get_current_admin)):
    """Удалить новость"""
    success = db.delete_news(news_id)
    if not success:
        raise HTTPException(status_code=404, detail="Новость не найдена")
    return {"message": "Новость удалена"}

# API для настроек
@admin_router.get("/api/settings")
async def get_settings_api(admin: str = Depends(get_current_admin)):
    """Получить все настройки"""
    return {"settings": db.get_all_settings()}

@admin_router.post("/api/settings")
async def update_setting_api(setting: AppSetting, admin: str = Depends(get_current_admin)):
    """Обновить настройку"""
    success = db.set_setting(setting.key, setting.value, setting.description)
    return {"message": "Настройка обновлена"}

# API для загрузки файлов
@admin_router.post("/api/upload")
async def upload_file(file: UploadFile = File(...), admin: str = Depends(get_current_admin)):
    """Загрузить изображение"""
    
    # Создаем папку uploads если её нет
    upload_dir = "uploads"
    os.makedirs(upload_dir, exist_ok=True)
    
    # Генерируем уникальное имя файла
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{timestamp}_{file.filename}"
    file_path = os.path.join(upload_dir, filename)
    
    # Сохраняем файл
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    # Возвращаем URL файла
    file_url = f"/admin/uploads/{filename}"
    return {"url": file_url, "filename": filename}

# Отдача загруженных файлов
@admin_router.get("/uploads/{filename}")
async def get_uploaded_file(filename: str):
    """Отдать загруженный файл"""
    file_path = os.path.join("uploads", filename)
    if os.path.exists(file_path):
        return FileResponse(file_path)
    raise HTTPException(status_code=404, detail="Файл не найден")

# API для статистики
@admin_router.get("/api/stats")
async def get_stats(admin: str = Depends(get_current_admin)):
    """Получить статистику"""
    stats = {
        "advertisements_count": len(db.get_advertisements()),
        "active_advertisements": len(db.get_advertisements(active_only=True)),
        "news_count": len(db.get_news()),
        "active_news": len(db.get_news(active_only=True)),
        "content_version": db.get_setting("content_version"),
        "last_update": datetime.now().isoformat(),
    }
    return stats

# API для отправки push-уведомлений (заглушка)
@admin_router.post("/api/push-notification")
async def send_push_notification(
    title: str = Form(...),
    message: str = Form(...),
    admin: str = Depends(get_current_admin)
):
    """Отправить push-уведомление (заглушка)"""
    # В будущем здесь будет интеграция с Apple Push Notification Service
    return {"message": f"Уведомление '{title}' отправлено (заглушка)"}

# Функция для генерации HTML админки
def get_admin_html():
    """Генерирует HTML страницу админки"""
    return '''
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Админ-панель MPT App</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: rgba(255,255,255,0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            margin-bottom: 30px;
            text-align: center;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2.5em;
            background: linear-gradient(45deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 10px;
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: rgba(255,255,255,0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 25px;
            text-align: center;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-5px);
        }
        
        .stat-number {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 5px;
        }
        
        .sections {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
        }
        
        .section {
            background: rgba(255,255,255,0.95);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        
        .section h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 1.5em;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .btn {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 10px;
            cursor: pointer;
            font-size: 14px;
            transition: all 0.3s ease;
            margin: 5px;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        
        .btn-danger {
            background: linear-gradient(45deg, #ff416c, #ff4b2b);
        }
        
        .btn-success {
            background: linear-gradient(45deg, #11998e, #38ef7d);
        }
        
        .form-group {
            margin-bottom: 15px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: 500;
            color: #555;
        }
        
        .form-group input,
        .form-group textarea,
        .form-group select {
            width: 100%;
            padding: 10px;
            border: 2px solid #e1e1e1;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.3s ease;
        }
        
        .form-group input:focus,
        .form-group textarea:focus,
        .form-group select:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .items-list {
            max-height: 400px;
            overflow-y: auto;
            margin-top: 20px;
        }
        
        .item {
            background: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 10px;
        }
        
        .item h4 {
            color: #667eea;
            margin-bottom: 5px;
        }
        
        .item p {
            color: #666;
            margin-bottom: 10px;
            font-size: 14px;
        }
        
        .item-actions {
            display: flex;
            gap: 10px;
        }
        
        .loading {
            text-align: center;
            color: #667eea;
            font-style: italic;
        }
        
        .success {
            background: #d4edda;
            color: #155724;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 15px;
        }
        
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 10px;
            border-radius: 5px;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎓 Админ-панель MPT App</h1>
            <p>Управление контентом приложения в реальном времени</p>
        </div>
        
        <div class="stats" id="stats">
            <div class="stat-card">
                <div class="stat-number" id="ads-count">-</div>
                <div>Всего реклам</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="news-count">-</div>
                <div>Всего новостей</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="content-version">-</div>
                <div>Версия контента</div>
            </div>
            <div class="stat-card">
                <div class="stat-number">🟢</div>
                <div>Сервер онлайн</div>
            </div>
        </div>
        
        <div class="sections">
            <!-- Управление рекламой -->
            <div class="section">
                <h2>📢 Управление рекламой</h2>
                <div id="ad-message"></div>
                
                <div class="form-group">
                    <label>Заголовок</label>
                    <input type="text" id="ad-title" placeholder="Название курса или сервиса">
                </div>
                
                <div class="form-group">
                    <label>Описание</label>
                    <textarea id="ad-description" placeholder="Краткое описание предложения" rows="3"></textarea>
                </div>
                
                <div class="form-group">
                    <label>Ссылка</label>
                    <input type="url" id="ad-link" placeholder="https://example.com">
                </div>
                
                <div class="form-group">
                    <label>Категория</label>
                    <select id="ad-category">
                        <option value="course">Курсы</option>
                        <option value="onlineSchool">Онлайн-школы</option>
                        <option value="service">Сервисы</option>
                    </select>
                </div>
                
                <button class="btn" onclick="createAd()">Добавить рекламу</button>
                <button class="btn" onclick="loadAds()">Обновить список</button>
                
                <div class="items-list" id="ads-list">
                    <div class="loading">Загрузка рекламы...</div>
                </div>
            </div>
            
            <!-- Управление новостями -->
            <div class="section">
                <h2>📰 Управление новостями</h2>
                <div id="news-message"></div>
                
                <div class="form-group">
                    <label>Название изображения</label>
                    <input type="text" id="news-image" placeholder="GeekMain (без расширения)">
                </div>
                
                <div class="form-group">
                    <label>Заголовок (опционально)</label>
                    <input type="text" id="news-title" placeholder="Заголовок новости">
                </div>
                
                <div class="form-group">
                    <label>Описание (опционально)</label>
                    <textarea id="news-description" placeholder="Описание новости" rows="3"></textarea>
                </div>
                
                <button class="btn" onclick="createNews()">Добавить новость</button>
                <button class="btn" onclick="loadNews()">Обновить список</button>
                
                <div class="items-list" id="news-list">
                    <div class="loading">Загрузка новостей...</div>
                </div>
            </div>
            
            <!-- Push-уведомления -->
            <div class="section">
                <h2>🔔 Push-уведомления</h2>
                <div id="push-message"></div>
                
                <div class="form-group">
                    <label>Заголовок</label>
                    <input type="text" id="push-title" placeholder="Новое обновление!">
                </div>
                
                <div class="form-group">
                    <label>Сообщение</label>
                    <textarea id="push-text" placeholder="Описание обновления..." rows="3"></textarea>
                </div>
                
                <button class="btn btn-success" onclick="sendPushNotification()">📱 Отправить уведомление</button>
            </div>
            
            <!-- Настройки -->
            <div class="section">
                <h2>⚙️ Настройки приложения</h2>
                <div id="settings-message"></div>
                
                <div class="form-group">
                    <label>Интервал показа рекламы (секунды)</label>
                    <input type="number" id="ad-duration" value="5" min="3" max="10">
                </div>
                
                <div class="form-group">
                    <label>Режим обслуживания</label>
                    <select id="maintenance-mode">
                        <option value="false">Выключен</option>
                        <option value="true">Включен</option>
                    </select>
                </div>
                
                <button class="btn" onclick="updateSettings()">Сохранить настройки</button>
                <button class="btn btn-danger" onclick="forceUpdate()">🚀 Принудительное обновление</button>
            </div>
        </div>
    </div>

    <script>
        // Загрузка статистики
        async function loadStats() {
            try {
                const response = await fetch('/admin/api/stats');
                const data = await response.json();
                
                document.getElementById('ads-count').textContent = data.advertisements_count;
                document.getElementById('news-count').textContent = data.news_count;
                document.getElementById('content-version').textContent = data.content_version;
            } catch (error) {
                console.error('Ошибка загрузки статистики:', error);
            }
        }
        
        // Загрузка рекламы
        async function loadAds() {
            try {
                const response = await fetch('/admin/api/advertisements');
                const data = await response.json();
                
                const container = document.getElementById('ads-list');
                container.innerHTML = '';
                
                data.advertisements.forEach(ad => {
                    container.innerHTML += `
                        <div class="item">
                            <h4>${ad.title}</h4>
                            <p>${ad.description}</p>
                            <p><strong>Категория:</strong> ${ad.category} | <strong>Активна:</strong> ${ad.is_active ? 'Да' : 'Нет'}</p>
                            <div class="item-actions">
                                <button class="btn" onclick="toggleAdStatus(${ad.id}, ${!ad.is_active})">${ad.is_active ? 'Деактивировать' : 'Активировать'}</button>
                                <button class="btn btn-danger" onclick="deleteAd(${ad.id})">Удалить</button>
                            </div>
                        </div>
                    `;
                });
            } catch (error) {
                document.getElementById('ads-list').innerHTML = '<div class="error">Ошибка загрузки рекламы</div>';
            }
        }
        
        // Создание рекламы
        async function createAd() {
            const title = document.getElementById('ad-title').value;
            const description = document.getElementById('ad-description').value;
            const link_url = document.getElementById('ad-link').value;
            const category = document.getElementById('ad-category').value;
            
            if (!title || !description) {
                showMessage('ad-message', 'Заполните обязательные поля', 'error');
                return;
            }
            
            try {
                const response = await fetch('/admin/api/advertisements', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ title, description, link_url, category })
                });
                
                if (response.ok) {
                    showMessage('ad-message', 'Реклама добавлена!', 'success');
                    document.getElementById('ad-title').value = '';
                    document.getElementById('ad-description').value = '';
                    document.getElementById('ad-link').value = '';
                    loadAds();
                    loadStats();
                } else {
                    throw new Error('Ошибка сервера');
                }
            } catch (error) {
                showMessage('ad-message', 'Ошибка при создании рекламы', 'error');
            }
        }
        
        // Переключение статуса рекламы
        async function toggleAdStatus(id, isActive) {
            try {
                const response = await fetch(`/admin/api/advertisements/${id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ is_active: isActive })
                });
                
                if (response.ok) {
                    loadAds();
                    loadStats();
                }
            } catch (error) {
                console.error('Ошибка при изменении статуса:', error);
            }
        }
        
        // Удаление рекламы
        async function deleteAd(id) {
            if (!confirm('Удалить эту рекламу?')) return;
            
            try {
                const response = await fetch(`/admin/api/advertisements/${id}`, {
                    method: 'DELETE'
                });
                
                if (response.ok) {
                    loadAds();
                    loadStats();
                }
            } catch (error) {
                console.error('Ошибка при удалении:', error);
            }
        }
        
        // Загрузка новостей
        async function loadNews() {
            try {
                const response = await fetch('/admin/api/news');
                const data = await response.json();
                
                const container = document.getElementById('news-list');
                container.innerHTML = '';
                
                data.news.forEach(news => {
                    container.innerHTML += `
                        <div class="item">
                            <h4>${news.title || 'Без заголовка'}</h4>
                            <p><strong>Изображение:</strong> ${news.image_url}</p>
                            <p>${news.description || 'Без описания'}</p>
                            <p><strong>Активна:</strong> ${news.is_active ? 'Да' : 'Нет'}</p>
                            <div class="item-actions">
                                <button class="btn" onclick="toggleNewsStatus(${news.id}, ${!news.is_active})">${news.is_active ? 'Деактивировать' : 'Активировать'}</button>
                                <button class="btn btn-danger" onclick="deleteNews(${news.id})">Удалить</button>
                            </div>
                        </div>
                    `;
                });
            } catch (error) {
                document.getElementById('news-list').innerHTML = '<div class="error">Ошибка загрузки новостей</div>';
            }
        }
        
        // Создание новости
        async function createNews() {
            const image_url = document.getElementById('news-image').value;
            const title = document.getElementById('news-title').value;
            const description = document.getElementById('news-description').value;
            
            if (!image_url) {
                showMessage('news-message', 'Укажите название изображения', 'error');
                return;
            }
            
            try {
                const response = await fetch('/admin/api/news', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ image_url, title, description })
                });
                
                if (response.ok) {
                    showMessage('news-message', 'Новость добавлена!', 'success');
                    document.getElementById('news-image').value = '';
                    document.getElementById('news-title').value = '';
                    document.getElementById('news-description').value = '';
                    loadNews();
                    loadStats();
                } else {
                    throw new Error('Ошибка сервера');
                }
            } catch (error) {
                showMessage('news-message', 'Ошибка при создании новости', 'error');
            }
        }
        
        // Переключение статуса новости
        async function toggleNewsStatus(id, isActive) {
            try {
                const response = await fetch(`/admin/api/news/${id}`, {
                    method: 'PUT',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ is_active: isActive })
                });
                
                if (response.ok) {
                    loadNews();
                    loadStats();
                }
            } catch (error) {
                console.error('Ошибка при изменении статуса:', error);
            }
        }
        
        // Удаление новости
        async function deleteNews(id) {
            if (!confirm('Удалить эту новость?')) return;
            
            try {
                const response = await fetch(`/admin/api/news/${id}`, {
                    method: 'DELETE'
                });
                
                if (response.ok) {
                    loadNews();
                    loadStats();
                }
            } catch (error) {
                console.error('Ошибка при удалении:', error);
            }
        }
        
        // Отправка push-уведомления
        async function sendPushNotification() {
            const title = document.getElementById('push-title').value;
            const message = document.getElementById('push-text').value;
            
            if (!title || !message) {
                showMessage('push-message', 'Заполните все поля', 'error');
                return;
            }
            
            try {
                const formData = new FormData();
                formData.append('title', title);
                formData.append('message', message);
                
                const response = await fetch('/admin/api/push-notification', {
                    method: 'POST',
                    body: formData
                });
                
                if (response.ok) {
                    showMessage('push-message', 'Уведомление отправлено! (заглушка)', 'success');
                    document.getElementById('push-title').value = '';
                    document.getElementById('push-text').value = '';
                } else {
                    throw new Error('Ошибка сервера');
                }
            } catch (error) {
                showMessage('push-message', 'Ошибка при отправке', 'error');
            }
        }
        
        // Обновление настроек
        async function updateSettings() {
            try {
                const adDuration = document.getElementById('ad-duration').value;
                const maintenanceMode = document.getElementById('maintenance-mode').value;
                
                await fetch('/admin/api/settings', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        key: 'featured_ad_duration',
                        value: adDuration,
                        description: 'Длительность показа рекламы (секунды)'
                    })
                });
                
                await fetch('/admin/api/settings', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        key: 'maintenance_mode',
                        value: maintenanceMode,
                        description: 'Режим обслуживания'
                    })
                });
                
                showMessage('settings-message', 'Настройки сохранены!', 'success');
            } catch (error) {
                showMessage('settings-message', 'Ошибка при сохранении', 'error');
            }
        }
        
        // Принудительное обновление
        async function forceUpdate() {
            if (!confirm('Отправить принудительное обновление всем пользователям?')) return;
            
            showMessage('settings-message', '🚀 Обновление отправлено!', 'success');
            loadStats();
        }
        
        // Показ сообщений
        function showMessage(elementId, message, type) {
            const element = document.getElementById(elementId);
            element.innerHTML = `<div class="${type}">${message}</div>`;
            setTimeout(() => {
                element.innerHTML = '';
            }, 3000);
        }
        
        // Инициализация
        document.addEventListener('DOMContentLoaded', function() {
            loadStats();
            loadAds();
            loadNews();
            
            // Автообновление статистики каждую минуту
            setInterval(loadStats, 60000);
        });
    </script>
</body>
</html>
    '''
