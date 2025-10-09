#!/bin/bash

# Значения по умолчанию
SNAPSHOT="false"
OUTPUT_DIR="./designsystem/library/"

# Разбираем именованные аргументы
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      NAME="$2"
      shift 2
      ;;
    --versionMajor)
      VERSION_MAJOR="$2"
      shift 2
      ;;
    --versionMinor)
      VERSION_MINOR="$2"
      shift 2
      ;;
    --versionPatch)
      VERSION_PATCH="$2"
      shift 2
      ;;
    --snapshot)
      SNAPSHOT="$2"
      shift 2
      ;;
    --outputDir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Неизвестный аргумент: $1"
      exit 1
      ;;
  esac
done

# Проверка обязательных параметров
if [ -z "$NAME" ] || [ -z "$VERSION_MAJOR" ] || [ -z "$VERSION_MINOR" ] || [ -z "$VERSION_PATCH" ]; then
  echo "Использование: $0 --name <artifactId> --versionMajor <X> --versionMinor <Y> --versionPatch <Z> [--snapshot true|false] [--outputDir <path>]"
  exit 1
fi

# Генерация вспомогательных переменных
THEME_ALIAS=$(echo "$NAME" | awk '{
  s=$0;
  gsub(/[^A-Za-z0-9]+/, " ", s);
  n=split(s, a, /[ ]+/);
  out="";
  for(i=1;i<=n;i++){
    w=a[i];
    if(length(w)>0){
      first=toupper(substr(w,1,1));
      rest=tolower(substr(w,2));
      out=out first rest;
    }
  }
  print out;
}')
ARTIFACT_ID=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')
THEME_RES_PREFIX="ds"
DOCS_THEME_NAME="$NAME"
NEXUS_DESCRIPTION=""


if [ "$COMPOSE" = "true" ]; then
  THEME_RES_PREFIX="${THEME_RES_PREFIX}_cmp"
  DOCS_THEME_PREFIX="${THEME_ALIAS}"
  NEXUS_DESCRIPTION="compose"
  DOCS_THEME_CODE_REFERENCE="${THEME_ALIAS}Theme"
  ARTIFACT_ID="${ARTIFACT_ID}-compose"
else
  DOCS_THEME_PREFIX="${THEME_ALIAS}"
  NEXUS_DESCRIPTION="view"
  DOCS_THEME_CODE_REFERENCE="Ds.${THEME_ALIAS}.MaterialComponents.DayNight"
fi


mkdir -p "$OUTPUT_DIR"
cat > "$OUTPUT_DIR/gradle.properties" <<EOL
nexus.artifactId=$ARTIFACT_ID
nexus.snapshot=$SNAPSHOT
nexus.description=$NAME token library for $NEXUS_DESCRIPTION framework
versionMajor=$VERSION_MAJOR
versionMinor=$VERSION_MINOR
versionPatch=$VERSION_PATCH

theme-alias=SddsService
theme-resPrefix=$THEME_RES_PREFIX
theme-package=com.$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '.' | tr '-' '_')
docs-theme-name=$DOCS_THEME_NAME
docs-theme-codeReference=$DOCS_THEME_CODE_REFERENCE
docs-theme-prefix=$DOCS_THEME_PREFIX
EOL

echo "✅ gradle.properties успешно создан в $OUTPUT_DIR"