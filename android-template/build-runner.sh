#!/usr/bin/env bash
set -euo pipefail

# Build helper for android runner image
#
# Usage examples:
#   ./build-runner.sh                          # build :dev for host platform
#   ./build-runner.sh --compose=true           # pass COMPOSE build-arg
#   ./build-runner.sh -n plasma/android-runner -t 0.1
#   ./build-runner.sh --platform linux/amd64   # build for amd64 on Apple Silicon
#   ./build-runner.sh --no-cache               # disable build cache
#

IMAGE_NAME="plasma/android-runner"
IMAGE_TAG="dev"
COMPOSE_ARG="false"
PLATFORM=""
NO_CACHE="false"
SAVE_PATH=""
DOCKERFILE="android_runner.Dockerfile"
CONTEXT_DIR="."

usage() {
  cat <<EOF
Build android runner Docker image (local only).

Options:
  -n, --name <name>        Image name (default: $IMAGE_NAME)
  -t, --tag <tag>          Image tag (default: $IMAGE_TAG)
      --compose <bool>     Build arg COMPOSE=true|false (default: $COMPOSE_ARG)
      --platform <plat>    e.g. linux/amd64 or linux/arm64
      --no-cache           Disable build cache
      --save <path>        Save image to a gzipped tar at <path>
  -h, --help               Show this help

Examples:
  ./build-runner.sh -n plasma/android-runner -t 0.1 --compose=true
  ./build-runner.sh --platform linux/amd64 --no-cache
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)
      IMAGE_NAME="$2"; shift 2;;
    -t|--tag)
      IMAGE_TAG="$2"; shift 2;;
    --compose)
      COMPOSE_ARG="$2"; shift 2;;
    --platform)
      PLATFORM="$2"; shift 2;;
    --no-cache)
      NO_CACHE="true"; shift 1;;
    --save)
      SAVE_PATH="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2
      usage; exit 1;;
  esac
done

# Pre-flight checks
if ! command -v docker >/dev/null 2>&1; then
  echo "❌ Docker is not installed or not in PATH" >&2
  exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "❌ Dockerfile '$DOCKERFILE' not found in $PWD" >&2
  exit 1
fi

# Build args
BUILD_ARGS=(
  -f "$DOCKERFILE"
  -t "$IMAGE_NAME:$IMAGE_TAG"
  --build-arg "COMPOSE=$COMPOSE_ARG"
  --label "project=android-runner"
)

if [[ -n "$PLATFORM" ]]; then
  BUILD_ARGS+=( --platform "$PLATFORM" )
fi

if [[ "$NO_CACHE" == "true" ]]; then
  BUILD_ARGS+=( --no-cache )
fi

set -x
DOCKER_BUILDKIT=1 docker build "${BUILD_ARGS[@]}" "$CONTEXT_DIR"
set +x

echo "✅ Built image: $IMAGE_NAME:$IMAGE_TAG (local Docker)"

if [[ -n "$SAVE_PATH" ]]; then
  echo "💾 Saving image to $SAVE_PATH ..."
  mkdir -p "$(dirname "$SAVE_PATH")"
  docker save "$IMAGE_NAME:$IMAGE_TAG" | gzip > "$SAVE_PATH"
  echo "✅ Saved to $SAVE_PATH"
fi

echo "ℹ️  To use it in another Dockerfile:"
echo "    FROM $IMAGE_NAME:$IMAGE_TAG"