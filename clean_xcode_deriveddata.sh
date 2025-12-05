#!/bin/bash

echo "🧹 Очистка кеша Xcode DerivedData..."

# Закрываем Xcode если он открыт
killall Xcode 2>/dev/null || true

# Удаляем DerivedData
echo "Удаление DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData

# Пересоздаем папку с правильными правами
mkdir -p ~/Library/Developer/Xcode/DerivedData
chmod 755 ~/Library/Developer/Xcode/DerivedData

# Очищаем дополнительные кеши
echo "Очистка дополнительных кешей..."
rm -rf ~/Library/Developer/Xcode/UserData/IDESwiftPackageProductService
rm -rf ~/Library/Caches/com.apple.dt.Xcode

echo "✅ Очистка завершена!"
echo "Теперь откройте Xcode заново."

