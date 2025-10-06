#!/usr/bin/env bash
set -euo pipefail

# === Конфигурация по умолчанию ===
REPO_URL="${REPO_URL:-https://github.com/salute-developers/plasma-android.git}"
BRANCH="${BRANCH:-main}"
SPARSE_PATH="${SPARSE_PATH:-build-system gradle}"
DO_COMMIT="${DO_COMMIT:-false}"   # true -> автоматически закоммитить обновление сабмодуля

# === Проверки окружения ===
if ! command -v git >/dev/null 2>&1; then
  echo "git не найден в PATH" >&2
  exit 1
fi

# Нужен Git >= 2.25 для удобного sparse-checkout (cone mode)
git_min_ver="2.25.0"
git_ver="$(git version | awk '{print $3}')"
if [ "$(printf '%s\n' "$git_min_ver" "$git_ver" | sort -V | head -n1)" != "$git_min_ver" ]; then
  echo "Внимание: рекомендуется Git >= ${git_min_ver}. Текущая версия: ${git_ver}" >&2
fi

# === Клонируем plasma-android во временную директорию (без следов в репозитории) ===
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

echo "Клонирую ${REPO_URL} во временную папку ${TMP_DIR} (ветка ${BRANCH})..."
git clone --depth 1 --branch "${BRANCH}" --filter=blob:none --sparse "${REPO_URL}" "${TMP_DIR}"
(
  cd "${TMP_DIR}"
  git sparse-checkout set ${SPARSE_PATH}
)

# === Зеркалируем директорию build-system из сабмодуля в build-system ===
echo "Зеркалирую ${TMP_DIR}/build-system -> build-system шаблона"
rm -rf build-system
mkdir -p build-system
cp -R "${TMP_DIR}/build-system/." build-system/

# === Зеркалим директорию gradle из репозитория plasma-android в gradle шаблона ===
echo "Зеркалирую ${TMP_DIR}/gradle -> gradle"
rm -rf gradle
mkdir -p gradle
cp -R "${TMP_DIR}/gradle/." gradle/

echo "Готово. Репозиторий plasma-android на ветке ${BRANCH}; sparse-checkout=${SPARSE_PATH}"
