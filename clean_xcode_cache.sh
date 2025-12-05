#!/bin/bash

# Скрипт для очистки кэша Xcode и профилей
# Помогает решить проблемы с регистрацией устройств

echo "🧹 Очистка кэша Xcode..."

# Остановка Xcode, если он запущен
echo "⏹️  Остановка Xcode..."
killall Xcode 2>/dev/null || true

# Очистка DerivedData
echo "🗑️  Очистка DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true

# Очистка старых профилей
echo "🗑️  Очистка старых профилей..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/* 2>/dev/null || true

# Очистка Archives
echo "🗑️  Очистка Archives..."
rm -rf ~/Library/Developer/Xcode/Archives/* 2>/dev/null || true

# Очистка кэша модулей
echo "🗑️  Очистка кэша модулей..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode/* 2>/dev/null || true

echo "✅ Очистка завершена!"
echo ""
echo "📋 Следующие шаги:"
echo "1. Откройте Xcode"
echo "2. Перейдите в Xcode > Settings > Accounts (или Preferences > Accounts)"
echo "3. Выберите ваш Apple ID"
echo "4. Нажмите 'Download Manual Profiles'"
echo "5. Попробуйте снова подключить устройство"
echo ""
echo "💡 Если проблема не решена:"
echo "   - Проверьте количество устройств в Apple Developer Portal"
echo "   - Удалите неиспользуемые устройства"
echo "   - См. инструкции в DEVICE_LIMIT_SOLUTION.md"

