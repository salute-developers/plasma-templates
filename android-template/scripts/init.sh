#!/usr/bin/env bash
set -euo pipefail

# Путь к исходному проекту внутри контекста сборки
SRC_ROOT=${SRC_ROOT:-/src/android-template}
# Целевая директория в образе
DEST_ROOT=${DEST_ROOT:-/work}

# Флаг выбора варианта (передаётся через --build-arg COMPOSE=true/false)

COMPOSE=${COMPOSE:-false}

# Копирование каталога с исключениями
copy_project_filtered() {
  local src_dir="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  (
    cd "$src_dir" && \
    tar \
      --exclude='build' --exclude='*/build' --exclude='*/build/*' \
      --exclude='.idea' --exclude='*/.idea' --exclude='*/.idea/*' \
      --exclude='.gradle' --exclude='*/.gradle' --exclude='*/.gradle/*' \
      --exclude='.gitignore' --exclude='*/.gitignore' \
      --exclude='local.properties' --exclude='*/local.properties' \
      -cf - .
  ) | (
    cd "$dest_dir" && tar -xf -
  )
}

echo ">> Копируем build-system"
mkdir -p "$DEST_ROOT/build-system"
cp -r "$SRC_ROOT/build-system/." "$DEST_ROOT/build-system"

if [ "$COMPOSE" = "true" ]; then
  echo ">> Копируем compose-project в designsystem"
  copy_project_filtered "$SRC_ROOT/compose-project" "$DEST_ROOT/designsystem"
else
  echo ">> Копируем xml-project в designsystem"
  copy_project_filtered "$SRC_ROOT/xml-project" "$DEST_ROOT/designsystem"
fi

echo ">> Копируем gradle"
mkdir -p "$DEST_ROOT/gradle"
cp -r "$SRC_ROOT/gradle/." "$DEST_ROOT/gradle"

echo ">> Содержимое $DEST_ROOT:"
ls -al "$DEST_ROOT"