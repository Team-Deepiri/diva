#!/usr/bin/env bash
# Clean messy local rebuild artifacts from bootstrap / pure-ELF / cc-link testing.
# Does NOT touch the pinned seed bootstrap/diva-linux-amd64 (only optional old .bak-* files).
#
# Usage (repo root or via path):
#   ./scripts/cleanup-dev-artifacts.sh           # safe defaults
#   ./scripts/cleanup-dev-artifacts.sh --dry-run
#   ./scripts/cleanup-dev-artifacts.sh --all     # also tmp + docker + seed backups
#   ./scripts/cleanup-dev-artifacts.sh --backups # remove bootstrap/diva-linux-amd64.bak-*
#   ./scripts/cleanup-dev-artifacts.sh --docker  # remove diva-sandbox containers
#
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/build"
BOOT_DIR="${ROOT_DIR}/bootstrap"

DRY_RUN=0
DO_ALL=0
DO_BACKUPS=0
DO_DOCKER=0
DO_TMP=0

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --all) DO_ALL=1; DO_BACKUPS=1; DO_DOCKER=1; DO_TMP=1 ;;
    --backups) DO_BACKUPS=1 ;;
    --docker) DO_DOCKER=1 ;;
    --tmp) DO_TMP=1 ;;
    -h|--help) usage 0 ;;
    *) echo "unknown flag: $arg" >&2; usage 1 ;;
  esac
done

rm_path() {
  local p=$1
  if [[ ! -e "$p" && ! -L "$p" ]]; then
    return 0
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[cleanup] would remove: $p"
    return 0
  fi
  rm -rf -- "$p"
  echo "[cleanup] removed: $p"
}

echo "[cleanup] root: ${ROOT_DIR}"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[cleanup] dry-run (no deletes)"
fi

# --- build/ work products & logs ---
BUILD_TARGETS=(
  "${BUILD_DIR}/merged-compiler.diva"
  "${BUILD_DIR}/merged-compiler.s"
  "${BUILD_DIR}/merged-compiler-stage2.s"
  "${BUILD_DIR}/diva-stage2"
  "${BUILD_DIR}/diva-stage2-from-cc"
  "${BUILD_DIR}/diva-compiler-pure-elf"
  "${BUILD_DIR}/diva-compiler-pure-elf-stage2"
  "${BUILD_DIR}/diva-compiler-pure-elf-stage3"
  "${BUILD_DIR}/diva-stage3"
  "${BUILD_DIR}/diva-stage3-native"
  "${BUILD_DIR}/diva-stage3-cc"
  "${BUILD_DIR}/diva-driver-merged"
  "${BUILD_DIR}/diva-driver-promote-candidate"
  "${BUILD_DIR}/stage2-build-compiler.out"
  "${BUILD_DIR}/stage3-build-compiler.out"
  "${BUILD_DIR}/stage3-cc-build-compiler.out"
  "${BUILD_DIR}/stage3-cc-pipeline.out"
  "${BUILD_DIR}/stage2-asm-merged.err"
  "${BUILD_DIR}/.promote-seed.log"
  "${BUILD_DIR}/.promote-seed.log.stage2"
  "${BUILD_DIR}/.merged-driver-build.log"
  "${BUILD_DIR}/.compiler-cc-link"
  "${BUILD_DIR}/.pure-elf-compiler"
  "${BUILD_DIR}/.promote-seed.log"
)

for f in "${BUILD_TARGETS[@]}"; do
  rm_path "$f"
done

# leftover logs / outs under build/
if [[ -d "$BUILD_DIR" ]]; then
  while IFS= read -r -d '' f; do
    rm_path "$f"
  done < <(find "$BUILD_DIR" -maxdepth 1 \( -name '*.log' -o -name '*.out' -o -name '*.err' \) -print0 2>/dev/null || true)
fi

# --- /tmp scratch from pipelines ---
if [[ "$DO_TMP" -eq 1 || "$DO_ALL" -eq 1 ]]; then
  for p in \
    /tmp/diva-native-exe \
    /tmp/diva-native-exe-stage2 \
    /tmp/diva-probe-exe \
    /tmp/diva-retry-exe \
    /tmp/diva-tiny.diva \
    /tmp/diva-sandbox
  do
    rm_path "$p"
  done
  # ephemeral verify temps
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[cleanup] would clear /tmp/tmp.*diva* /tmp/diva-* (glob)"
  else
    rm -f /tmp/diva-* 2>/dev/null || true
    echo "[cleanup] cleared /tmp/diva-* (best-effort)"
  fi
fi

# --- seed backups (never the live seed) ---
if [[ "$DO_BACKUPS" -eq 1 ]]; then
  if [[ -d "$BOOT_DIR" ]]; then
    while IFS= read -r -d '' f; do
      rm_path "$f"
    done < <(find "$BOOT_DIR" -maxdepth 1 -type f \( -name 'diva-linux-amd64.bak-*' -o -name 'diva-linux-amd64.bak' \) -print0 2>/dev/null || true)
  fi
fi

# --- docker one-shot sandboxes ---
if [[ "$DO_DOCKER" -eq 1 ]]; then
  if command -v docker >/dev/null 2>&1; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      docker ps -a --filter name=diva-sandbox --format '[cleanup] would docker rm -f {{.Names}}' 2>/dev/null || true
    else
      ids=$(docker ps -aq --filter name=diva-sandbox 2>/dev/null || true)
      if [[ -n "${ids}" ]]; then
        # shellcheck disable=SC2086
        docker rm -f $ids >/dev/null
        echo "[cleanup] removed docker containers matching diva-sandbox"
      else
        echo "[cleanup] no diva-sandbox containers"
      fi
    fi
  else
    echo "[cleanup] docker not installed; skip"
  fi
fi

echo "[cleanup] done (pinned seed bootstrap/diva-linux-amd64 left alone)"
