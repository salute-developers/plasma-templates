#!/usr/bin/env bash
set -euo pipefail

log() { echo "[runner] $*"; }

WORKDIR="$PWD/designsystem/"
OUTDIR="${OUTDIR:-/tmp/builds/${BUILD_ID}/out}"

mkdir -p "$OUTDIR"
mkdir -p "$OUTDIR/lib"
mkdir -p "$OUTDIR/docs"

mkdir -p "$WORKDIR"

cd "$WORKDIR"

log "Generating tokens ..."
chmod +x ./gradlew
./gradlew --no-daemon :library:generateTheme

log "Generating components ..."
chmod +x ./gradlew
./gradlew --no-daemon :library:generateComponents

log "Assembling library artifacts ..."
chmod +x ./gradlew
./gradlew --no-daemon :library:assemble -PbranchName=main

log "Generating documentation ..."
chmod +x ./gradlew
./gradlew --no-daemon :library:docusaurusBuild -PbranchName=main

log "Collecting artifacts ..."
find . -path "*/library/build/outputs/aar/*.aar" -type f -exec cp {} "$OUTDIR/lib" \; || true

if [ -d "./library/build/generated/docusaurus/build" ]; then
  log "Copying Docusaurus site output ..."
  cp -r ./library/build/generated/docusaurus/build/. "$OUTDIR/docs"/ || true
fi

log "Artifacts saved to $OUTDIR"
ls -lh "$OUTDIR" || true

log "Build finished successfully"