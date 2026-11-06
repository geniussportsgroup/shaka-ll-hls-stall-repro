#!/usr/bin/env bash
# Copy a locally built shaka-player.compiled.js into vendor/ for A/B testing.
#
# Usage:
#   ./refresh-fixed-build.sh /path/to/shaka-player
#   SHAKA_PLAYER_DIR=/path/to/shaka-player ./refresh-fixed-build.sh
#
# Looks for dist/shaka-player.compiled.js (or dist/shaka-player.compiled.debug.js
# as a fallback) under the given checkout.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC_ROOT="${1:-${SHAKA_PLAYER_DIR:-}}"

if [[ -z "${SRC_ROOT}" ]]; then
  echo "Usage: $0 <shaka-player-checkout>" >&2
  echo "   or: SHAKA_PLAYER_DIR=<checkout> $0" >&2
  exit 1
fi

if [[ ! -d "${SRC_ROOT}" ]]; then
  echo "Not a directory: ${SRC_ROOT}" >&2
  exit 1
fi

CANDIDATES=(
  "${SRC_ROOT}/dist/shaka-player.compiled.js"
  "${SRC_ROOT}/dist/shaka-player.compiled.debug.js"
)

SRC=""
for c in "${CANDIDATES[@]}"; do
  if [[ -f "${c}" ]]; then
    SRC="${c}"
    break
  fi
done

if [[ -z "${SRC}" ]]; then
  echo "No compiled bundle found under ${SRC_ROOT}/dist/" >&2
  echo "Build Shaka first (e.g. python3 build/build.py), then re-run." >&2
  exit 1
fi

mkdir -p "${ROOT}/vendor"
DEST="${ROOT}/vendor/shaka-player.fixed.compiled.js"
cp -f "${SRC}" "${DEST}"
echo "Updated ${DEST}"
echo "  from ${SRC}"
echo "  size $(wc -c < "${DEST}") bytes"
echo "Reload the repro page and choose: This branch fix (local vendor build)"
