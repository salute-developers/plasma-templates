#!/usr/bin/env sh

# Скрипт запуска ds-generator CLI, а затем publisher CLI с передачей параметров
# Пример:
#   ./publish.sh \
#       --ds-name my-ds --ds-version 1.0.0 --export-type tgz --output ./out \
#       --token $NPM_TOKEN

set -e

# Пути к собранным CLI
PUBLISHER_BIN="/app/publisher.js"

if [ ! -f "$PUBLISHER_BIN" ]; then
  echo "[ERROR] publisher CLI не найден: $PUBLISHER_BIN"
  echo "Подсказка: запусти 'npm run build' в services/publisher"
  exit 1
fi

# Разбираем параметры CLI (POSIX sh)
ds_args=""
token=""

# Пройдём по всем аргументам, выкинув --token и его значение, и запомним --output
set -- "$@"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --token)
      token="$2"
      shift 2
      continue
      ;;
  esac

  ds_args="$ds_args $(printf '%s' "$1")"
  shift
done

output_dir="/tmp/builds/${BUILD_ID}/out"
ds_output="/app/ds-generator/out"

# Восстанавливаем позиционные параметры из ds_args (без кавычек, чтобы разбить по IFS)
set -- $ds_args

# Запускаем генерацию дизайн-системы

echo "[INFO] Запуск ds-generator CLI из локального проекта..."
DS_PROJECT_DIR="/app/ds-generator"
GEN_BIN_NAME="plasma-ds-generate"
GEN_BIN_PATH="$DS_PROJECT_DIR/node_modules/.bin/$GEN_BIN_NAME"

if command -v "$GEN_BIN_NAME" >/dev/null 2>&1; then
  RUN_CMD="$GEN_BIN_NAME"
elif [ -x "$GEN_BIN_PATH" ]; then
  RUN_CMD="$GEN_BIN_PATH"
elif [ -f "$DS_PROJECT_DIR/dist/cli.js" ]; then
  RUN_CMD="node $DS_PROJECT_DIR/dist/cli.js"
elif [ -f "$DS_PROJECT_DIR/cli.js" ]; then
  RUN_CMD="node $DS_PROJECT_DIR/cli.js"
else
  echo "[ERROR] Не найден исполняемый файл генератора ($GEN_BIN_NAME) или cli.js в $DS_PROJECT_DIR"
  exit 1
fi

# Выполняем из корня проекта, чтобы работали относительные пути и конфиги
cd "$DS_PROJECT_DIR"
$RUN_CMD "$@" --output "$ds_output"
cd - >/dev/null 2>&1 || true

# Определяем tgz файл
TGZ_FILE=$(find "$ds_output" -maxdepth 1 -type f -name "*.tgz" | sort | tail -n 1)
if [ -z "$TGZ_FILE" ]; then
  echo "[ERROR] Не найден .tgz файл в $ds_output"
  exit 1
fi


echo "[INFO] Найден пакет: $TGZ_FILE"
tar -tzf "$TGZ_FILE"

echo "[INFO] Копируем пакет в $output_dir..."
mkdir -p "$output_dir/lib"
cp "$TGZ_FILE" "$output_dir/lib"

# Запуск publisher
if [ -z "$token" ]; then
  echo "[ERROR] Не указан токен (--token)"
  exit 1
fi

echo "[INFO] Запуск publisher CLI..."
# sleep 600
node "$PUBLISHER_BIN" dry-run "$TGZ_FILE" # --token "$token"
