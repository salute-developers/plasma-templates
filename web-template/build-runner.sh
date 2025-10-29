#!/usr/bin/env sh

# Примеры запуска:
#   ./build-runner.sh                # Использует ветку master
#   ./build-runner.sh feature/branch # Использует указанную ветку feature/branch

set -e

# Переходим в корень runner
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRANCH="${1:-master}"
echo "[INFO] Используется ветка: $BRANCH"

# 0. Получаем нужные директории из репозитория design-system-builder
TEMP_CLONE_DIR="$(mktemp -d)"
echo "[INFO] Клонируем необходимые сервисы из design-system-builder..."

git clone --depth 1 --branch "$BRANCH" --filter=blob:none --sparse https://github.com/salute-developers/design-system-builder.git "$TEMP_CLONE_DIR"
cd "$TEMP_CLONE_DIR"
git sparse-checkout set services/publisher services/ds-generator

# Копируем только нужные директории
cp -r services/publisher "$TEMP_CLONE_DIR/services/publisher"
cp -r services/ds-generator "$TEMP_CLONE_DIR/services/ds-generator"

# 1. Сборка publisher
cd "$TEMP_CLONE_DIR/services/publisher"
echo "[INFO] Сборка publisher..."

npm install && npm run build

# 2. Сборка ds-generator (CLI)
cd "$TEMP_CLONE_DIR/services/ds-generator"
echo "[INFO] Пакуем содержимое проекта ds-generator в архив..."
NEW_NAME="ds-generator-cli.tgz"
tar --exclude node_modules \
    --exclude .git \
    --exclude .idea \
    --exclude dist \
    --exclude .vscode \
    -czf "$TEMP_CLONE_DIR/$NEW_NAME" -C "$TEMP_CLONE_DIR/services/ds-generator" .
echo "[INFO] Сформирован архив: $NEW_NAME"

tar -tzf "$TEMP_CLONE_DIR/$NEW_NAME"

# 3. Копируем артефакты в runner
cd "$TEMP_CLONE_DIR"
echo "[INFO] Копируем артефакты..."
cp "$TEMP_CLONE_DIR/services/publisher/dist/publisher.js" "$TEMP_CLONE_DIR/publisher.js"
echo "[INFO] Копируем финальные артефакты в $SCRIPT_DIR..."
cp "$TEMP_CLONE_DIR/$NEW_NAME" "$SCRIPT_DIR/"
cp "$TEMP_CLONE_DIR/publisher.js" "$SCRIPT_DIR/"

# 4. Сборка Docker образа
cd "$SCRIPT_DIR"
IMAGE_NAME="plasma/web-runner:dev"
echo "[INFO] Сборка Docker образа $IMAGE_NAME..."
docker build -t "$IMAGE_NAME" -f runner.Dockerfile .

echo "[INFO] Удаляем временные файлы..."
rm -rf "$TEMP_CLONE_DIR"
rm -rf "${SCRIPT_DIR:?}/$NEW_NAME"
rm -rf "${SCRIPT_DIR:?}/publisher.js"

echo "[INFO] Готово. Образ собран: $IMAGE_NAME"