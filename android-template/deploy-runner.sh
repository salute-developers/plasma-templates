#!/usr/bin/env bash
set -euo pipefail

#############################################
# deploy-runner.sh — upload sources (android-template) and build on server via build-runner
#############################################

#
# Usage:
#   ./deploy-runner.sh [args]
#
# Required arguments:
#   --ssh-dest user@host            # remote SSH destination
# Optional arguments:
#   --ssh-key ~/.ssh/id_rsa         # path to private SSH key
#   --ssh-port 22                   # SSH port
#   --remote-dir /opt/project-publisher  # remote base dir
#   --template-dir <path>          # path to android-template (defaults smartly)
#
# Example:
#   ./deploy-runner.sh --ssh-dest user@192.168.1.10 --ssh-key ~/.ssh/id_rsa --ssh-port 2222 --platform linux/amd64 --no-cache
#

log() { echo "[deploy] $*"; }
err() { echo "[err]  $*" >&2; }
_die() { err "$1"; exit 1; }
_dbg() { [[ -n "${SSH_DEBUG:-}" ]] && echo "[ssh-debug] $*" >&2 || true; }

SSH_DEST=""
SSH_KEY=""
SSH_PORT="22"
REMOTE_DIR="/opt/project-publisher"
SSH_JUMP=""
SSH_CONNECT_TIMEOUT="10"
SSH_KEEPALIVE_INTERVAL="15"
SSH_KEEPALIVE_COUNT="3"
SSH_STRICT_HOST_KEY_CHECKING="accept-new"
SSH_DEBUG=""

# ----------------------
# Argument parsing
# ----------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ssh-dest)
      if [[ -z "${2:-}" ]]; then
        _die "--ssh-dest requires an argument"
      fi
      SSH_DEST="$2"
      shift 2
      ;;
    --ssh-key)
      if [[ -z "${2:-}" ]]; then
        _die "--ssh-key requires an argument"
      fi
      SSH_KEY="$2"
      shift 2
      ;;
    --ssh-port)
      if [[ -z "${2:-}" ]]; then
        _die "--ssh-port requires an argument"
      fi
      SSH_PORT="$2"
      shift 2
      ;;
    --remote-dir)
      if [[ -z "${2:-}" ]]; then
        _die "--remote-dir requires an argument"
      fi
      REMOTE_DIR="$2"
      shift 2
      ;;
    --template-dir)
      if [[ -z "${2:-}" ]]; then
        _die "--template-dir requires an argument"
      fi
      TEMPLATE_DIR="$2"
      shift 2
      ;;
    --ssh-jump)
      if [[ -z "${2:-}" ]]; then
        _die "--ssh-jump requires an argument"
      fi
      SSH_JUMP="$2"
      shift 2
      ;;
    --) # end of options
      shift
      break
      ;;
    -*)
      # unknown option or option for build-runner.sh
      break
      ;;
    *)
      # positional argument, break to pass to build-runner.sh
      break
      ;;
  esac
done

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"     # корень репозитория
if [[ -z "${TEMPLATE_DIR:-}" ]]; then
  if [[ -d "$PROJECT_DIR/android-template" ]]; then
    TEMPLATE_DIR="$PROJECT_DIR/android-template"
  elif [[ "$(basename "$PROJECT_DIR")" == "android-template" ]]; then
    TEMPLATE_DIR="$PROJECT_DIR"
  else
    TEMPLATE_DIR="$PROJECT_DIR/android-template"
  fi
fi
REMOTE_PROJECT_DIR="$REMOTE_DIR/android-template"      # куда раскладываем шаблон

# ----------------------
# Args passthrough to build-runner.sh
# ----------------------
# Any positional args given to deploy-runner.sh will be forwarded to build-runner.sh on the server.
BUILD_RUNNER_ARGS=("$@")
_escape_args() { local a=(); local x; for x in "$@"; do a+=("$(printf '%q' "$x")"); done; printf '%s' "${a[*]}"; }
BUILD_RUNNER_ARGS_ESC="$(_escape_args "${BUILD_RUNNER_ARGS[@]}")"

[[ -n "$SSH_DEST" ]] || _die "SSH destination is required (--ssh-dest user@host)."
[[ -d "$TEMPLATE_DIR" ]] || _die "android-template dir not found: $TEMPLATE_DIR (use --template-dir <path> or run from repo root or android-template folder)"

# ----------------------
# SSH/SCP args
# ----------------------
SSH_ARGS=("-p" "$SSH_PORT")
SCP_ARGS=("-P" "$SSH_PORT")
if [[ -n "$SSH_KEY" ]]; then
  [[ "$SSH_KEY" == ~* ]] && SSH_KEY="${SSH_KEY/#~/$HOME}"
  if [[ "$SSH_KEY" != /* ]]; then SSH_KEY="$(cd "${SSH_KEY%/*}" 2>/dev/null && pwd)/${SSH_KEY##*/}"; fi
  [[ -f "$SSH_KEY" ]] || _die "SSH key not found at: $SSH_KEY"
  SSH_ARGS+=("-i" "$SSH_KEY"); SCP_ARGS+=("-i" "$SSH_KEY")
fi
[[ -n "$SSH_JUMP" ]] && { SSH_ARGS+=("-J" "$SSH_JUMP"); SCP_ARGS+=("-o" "ProxyJump=$SSH_JUMP"); }
SSH_ARGS+=("-o" "ConnectTimeout=$SSH_CONNECT_TIMEOUT" \
          "-o" "ServerAliveInterval=$SSH_KEEPALIVE_INTERVAL" \
          "-o" "ServerAliveCountMax=$SSH_KEEPALIVE_COUNT" \
          "-o" "StrictHostKeyChecking=$SSH_STRICT_HOST_KEY_CHECKING")
SCP_ARGS+=("-o" "ConnectTimeout=$SSH_CONNECT_TIMEOUT" \
          "-o" "ServerAliveInterval=$SSH_KEEPALIVE_INTERVAL" \
          "-o" "ServerAliveCountMax=$SSH_KEEPALIVE_COUNT" \
          "-o" "StrictHostKeyChecking=$SSH_STRICT_HOST_KEY_CHECKING")

# ----------------------
# Connectivity preflight
# ----------------------
log "Checking SSH connectivity..."
if ! ssh "${SSH_ARGS[@]}" ${SSH_DEBUG:+-vvv} -o BatchMode=yes "$SSH_DEST" "echo ok" >/dev/null 2>&1; then
  _die "SSH connectivity failed. Check host/port/firewall, key, or use SSH_JUMP."
fi

# ----------------------
# Pack context (android-template, with excludes)
# ----------------------
ART_DIR="$(mktemp -d)"; trap 'rm -rf "$ART_DIR" >/dev/null 2>&1 || true' EXIT
CONTEXT_TAR="$ART_DIR/context.tar.gz"

# Пакуем, исключая мусор и скрипты деплоя
pushd "$TEMPLATE_DIR" >/dev/null
log "Packing contents of android-template -> $CONTEXT_TAR"
COPYFILE_DISABLE=1 tar -czf "$CONTEXT_TAR" \
  --exclude "./.idea" \
  --exclude "./**/.idea" \
  --exclude "./.gradle" \
  --exclude "./**/.gradle" \
  --exclude "./build" \
  --exclude "./**/build" \
  --exclude "./deploy-*.sh" \
  --exclude "./update-plasma-build-system.sh" \
  .
popd >/dev/null

[[ -s "$CONTEXT_TAR" ]] || _die "Context archive is empty."

# ----------------------
# Upload & remote build via build-runner.sh (no compose up)
# ----------------------
ssh "${SSH_ARGS[@]}" "$SSH_DEST" "mkdir -p '$REMOTE_DIR' '$REMOTE_PROJECT_DIR'" || _die "Failed to create remote dir"
scp "${SCP_ARGS[@]}" "$CONTEXT_TAR" "$SSH_DEST:$REMOTE_PROJECT_DIR/" || _die "SCP context.tar.gz failed"

log "Uploading sources and building image on server via build-runner.sh (no container start)"
ssh "${SSH_ARGS[@]}" "$SSH_DEST" \
  "set -euo pipefail; \
   cd '$REMOTE_DIR' && \
   mkdir -p '$REMOTE_PROJECT_DIR' && \
   cd '$REMOTE_PROJECT_DIR' && \
   # Clean previous contents except the uploaded archive (if present)
   find . -mindepth 1 -maxdepth 1 ! -name 'context.tar.gz' -exec rm -rf {} + || true && \
   # Extract the new context into the project directory
   tar -xzf 'context.tar.gz' -C . && \
   rm -f 'context.tar.gz' && \
   if [ -f '$REMOTE_PROJECT_DIR/build-runner.sh' ]; then \
     chmod +x '$REMOTE_PROJECT_DIR/build-runner.sh' || true; \
     echo '[deploy] Running build-runner.sh on server with args: ${BUILD_RUNNER_ARGS_ESC}'; \
     ( cd '$REMOTE_PROJECT_DIR' && ./build-runner.sh ${BUILD_RUNNER_ARGS_ESC} ); \
   else \
     echo '[deploy] ERROR: build-runner.sh not found in $REMOTE_PROJECT_DIR'; \
     exit 1; \
   fi && \
   docker image prune -f --filter \"label=project=android-runner\" >/dev/null 2>&1 || true" \
  || _die "Remote build failed"

log "✅ Done: image built on server (no containers started)."