#!/usr/bin/env bash
set -euo pipefail

# Debug mode: keep the container alive if a step fails
DEBUG_STAY_ALIVE="${DEBUG_STAY_ALIVE:-false}"
stay_alive() {
  echo "[runner] DEBUG_STAY_ALIVE is true — keeping container alive for debugging"
  tail -f /dev/null
}

/app/publish.sh "$@" || {
  ec=$?
  echo "[runner] publish.sh failed with exit code $ec"
  if [[ "$DEBUG_STAY_ALIVE" == "true" ]]; then stay_alive; fi
  exit $ec
}
