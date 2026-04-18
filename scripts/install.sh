#!/usr/bin/env bash
# Installs Diva seed, runtime, stdlib, and (when possible) the Diva-built driver.
# Requires bash for correct pipeline exit codes when tee-ing the compiler build.
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL_DIR="${HOME}/.local/bin"
DIVA_SHARE="${XDG_DATA_HOME:-${HOME}/.local/share}/diva"
RUNTIME_DIR="${DIVA_SHARE}/runtime"
STDLIB_DIR="${DIVA_SHARE}/stdlib"
BOOTSTRAP_DIR="${DIVA_SHARE}/bootstrap"
LIBEXEC_DIR="${DIVA_SHARE}/libexec"
RUNTIME_O="${RUNTIME_DIR}/runtime.o"
SEED="${ROOT_DIR}/bootstrap/diva-linux-amd64"
BUILD_LOG="${DIVA_SHARE}/.compiler-build.log"
TRACE_LOG="${DIVA_SHARE}/install.log"
QUIET="${DIVA_INSTALL_QUIET:-0}"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

# Log to stderr (always visible) and append to TRACE_LOG when writable.
log() {
  local line="[diva-install] $*"
  printf '%s %s\n' "$(ts)" "${line}" >&2
  if [ -n "${TRACE_LOG}" ]; then
    printf '%s %s\n' "$(ts)" "${line}" >>"${TRACE_LOG}" 2>/dev/null || true
  fi
}

hr() {
  log "======== $* ========"
}

die() {
  log "ERROR: $*"
  exit 1
}

mkdir -p "${ROOT_DIR}/build"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${RUNTIME_DIR}"
mkdir -p "${STDLIB_DIR}"
mkdir -p "${BOOTSTRAP_DIR}"
mkdir -p "${LIBEXEC_DIR}"

{
  echo ""
  echo "===== diva install session $(ts) pid=$$ ====="
} >>"${TRACE_LOG}"

hr "start"
log "ROOT_DIR=${ROOT_DIR}"
log "DIVA_SHARE=${DIVA_SHARE}"
log "SEED=${SEED}"
log "TRACE_LOG=${TRACE_LOG} (append)"
log "QUIET=${QUIET} (set DIVA_INSTALL_QUIET=1 to send compiler build only to ${BUILD_LOG})"

hr "runtime object"
if [ -f "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" ]; then
  log "Copying prebuilt runtime-linux-amd64.o -> ${RUNTIME_O}"
  cp -v "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${RUNTIME_O}" >&2
elif [ "${NO_CLANG:-}" = "1" ]; then
  die "NO_CLANG=1 but missing ${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
elif command -v clang >/dev/null 2>&1 && [ -f "${ROOT_DIR}/runtime/runtime.ll" ]; then
  log "Compiling runtime.ll with clang -> ${RUNTIME_O}"
  clang -c -O1 "${ROOT_DIR}/runtime/runtime.ll" -o "${RUNTIME_O}"
  log "clang finished (runtime.o size=$(wc -c <"${RUNTIME_O}") bytes)"
else
  die "Need bootstrap/runtime-linux-amd64.o, or runtime/runtime.ll and clang in PATH"
fi

hr "stdlib copy"
log "Copying stdlib ${ROOT_DIR}/stdlib -> ${STDLIB_DIR}"
cp -R "${ROOT_DIR}/stdlib/." "${STDLIB_DIR}/"
log "stdlib files: $(find "${STDLIB_DIR}" -type f | wc -l) regular files"

hr "legacy di runtime path"
LEGACY_DI_SHARE="${HOME}/.local/share/di"
mkdir -p "${LEGACY_DI_SHARE}/runtime"
cp -v "${RUNTIME_O}" "${LEGACY_DI_SHARE}/runtime/runtime.o" >&2

hr "bootstrap seed"
[ -f "${SEED}" ] || die "Missing seed: ${SEED}"
log "Seed size=$(wc -c <"${SEED}") bytes; copying to ${BOOTSTRAP_DIR}/diva-linux-amd64"
cp -v "${SEED}" "${BOOTSTRAP_DIR}/diva-linux-amd64" >&2
chmod +x "${BOOTSTRAP_DIR}/diva-linux-amd64"

hr "compiler package build (slow)"
log "This step can take many minutes and use a lot of RAM."
log "Full build output: ${BUILD_LOG}"
rm -f "${BUILD_LOG}"
seed_rc=0
if [ "${QUIET}" = "1" ]; then
  log "QUIET=1: build output only in ${BUILD_LOG} (no live tee)"
  set +e
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
    "${SEED}" build "${ROOT_DIR}/compiler" >"${BUILD_LOG}" 2>&1
  seed_rc=$?
  set -e
else
  log "Streaming build to terminal and ${BUILD_LOG} (set DIVA_INSTALL_QUIET=1 to disable stream)"
  set +e
  if command -v stdbuf >/dev/null 2>&1; then
    DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
      stdbuf -oL -eL "${SEED}" build "${ROOT_DIR}/compiler" 2>&1 | tee "${BUILD_LOG}"
  else
    DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
      "${SEED}" build "${ROOT_DIR}/compiler" 2>&1 | tee "${BUILD_LOG}"
  fi
  seed_rc=${PIPESTATUS[0]}
  set -e
fi

DRIVER_INSTALLED=0
if [ "${seed_rc}" -eq 0 ]; then
  DRIVER=$(sed -n 's/^\[native\] built executable at //p' "${BUILD_LOG}" | tail -n 1)
  if [ -z "${DRIVER}" ]; then
    DRIVER=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD_LOG}" | tail -n 1)
  fi
  if [ -n "${DRIVER}" ] && [ -x "${DRIVER}" ]; then
    log "Build succeeded; driver path from log: ${DRIVER}"
    cp -v "${DRIVER}" "${LIBEXEC_DIR}/diva-driver" >&2
    chmod +x "${LIBEXEC_DIR}/diva-driver"
    DRIVER_INSTALLED=1
  else
    log "Build exited 0 but no executable path found in log (expected \"[native] built executable at\" or legacy \"[di] built native executable at\")"
    log "Last 40 lines of ${BUILD_LOG}:"
    tail -n 40 "${BUILD_LOG}" >&2 || true
  fi
else
  log "Compiler build failed (exit ${seed_rc}). See ${BUILD_LOG}"
  log "Last 60 lines of ${BUILD_LOG}:"
  tail -n 60 "${BUILD_LOG}" >&2 || true
fi

hr "install wrapper / binaries"
if [ "${DRIVER_INSTALLED}" = "1" ]; then
  cat >"${INSTALL_DIR}/diva" <<'WRAPPER'
#!/usr/bin/env sh
set -e
_DIVA_DATA="${XDG_DATA_HOME:-${HOME}/.local/share}/diva"
_BOOT="${_DIVA_DATA}/bootstrap/diva-linux-amd64"
export DIVA_BOOTSTRAP="${_BOOT}"
export DI_BOOTSTRAP="${_BOOT}"
export DI_STDLIB_DIR="${DI_STDLIB_DIR:-${_DIVA_DATA}/stdlib}"
export DI_RUNTIME_O="${DI_RUNTIME_O:-${_DIVA_DATA}/runtime/runtime.o}"
exec "${_DIVA_DATA}/libexec/diva-driver" "$@"
WRAPPER
  chmod +x "${INSTALL_DIR}/diva"
  ln -sfv diva "${INSTALL_DIR}/di" 2>/dev/null || true
  log "Installed diva-driver wrapper -> ${INSTALL_DIR}/diva"
else
  log "WARNING: installing seed only as ${INSTALL_DIR}/diva (no diva lex / native driver)"
  cp -v "${BOOTSTRAP_DIR}/diva-linux-amd64" "${INSTALL_DIR}/diva" >&2
  chmod +x "${INSTALL_DIR}/diva"
  ln -sfv diva "${INSTALL_DIR}/di" 2>/dev/null || true
fi

hr "done"
echo ""
echo "Installed diva to ${INSTALL_DIR}/diva (and di -> diva when supported)"
echo "Installed runtime object to ${RUNTIME_O}"
echo "Installed stdlib to ${STDLIB_DIR}"
echo "Installed bootstrap seed to ${BOOTSTRAP_DIR}/diva-linux-amd64"
if [ "${DRIVER_INSTALLED}" = "1" ]; then
  echo "Installed Diva-authored driver to ${LIBEXEC_DIR}/diva-driver (lexer + seed forward)"
fi
echo ""
echo "Install trace log: ${TRACE_LOG}"
echo "Compiler build log: ${BUILD_LOG}"
echo ""
echo "Add to your environment (e.g. ~/.profile):"
echo "  export PATH=\"${INSTALL_DIR}:\${PATH}\""
echo "  export DI_STDLIB_DIR=\"${STDLIB_DIR}\""
echo "  export DI_RUNTIME_O=\"${RUNTIME_O}\""
echo ""
echo "DIVA_BOOTSTRAP / DI_BOOTSTRAP are set by the diva wrapper to \${XDG_DATA_HOME:-\$HOME/.local/share}/diva/bootstrap/diva-linux-amd64"
echo "Linking user programs still uses the system linker driver (cc); there are no C sources in this repository."

log "Finished successfully (driver_installed=${DRIVER_INSTALLED})"
