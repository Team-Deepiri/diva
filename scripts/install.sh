#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL_DIR="${HOME}/.local/bin"
DIVA_SHARE="${XDG_DATA_HOME:-${HOME}/.local/share}/diva"
RUNTIME_DIR="${DIVA_SHARE}/runtime"
STDLIB_DIR="${DIVA_SHARE}/stdlib"
BOOTSTRAP_DIR="${DIVA_SHARE}/bootstrap"
LIBEXEC_DIR="${DIVA_SHARE}/libexec"
RUNTIME_O="${RUNTIME_DIR}/runtime.o"
SEED="${ROOT_DIR}/bootstrap/diva-linux-amd64"

mkdir -p "${ROOT_DIR}/build"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${RUNTIME_DIR}"
mkdir -p "${STDLIB_DIR}"
mkdir -p "${BOOTSTRAP_DIR}"
mkdir -p "${LIBEXEC_DIR}"

if [ "${NO_CLANG:-}" = "1" ]; then
  if [ ! -f "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" ]; then
    echo "NO_CLANG=1: missing ${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" >&2
    exit 1
  fi
  cp "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${RUNTIME_O}"
elif command -v clang >/dev/null 2>&1 && [ -f "${ROOT_DIR}/runtime/runtime.ll" ]; then
  clang -c -O1 "${ROOT_DIR}/runtime/runtime.ll" -o "${RUNTIME_O}"
elif [ -f "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" ]; then
  cp "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${RUNTIME_O}"
else
  echo "Need runtime/runtime.ll and clang, or bootstrap/runtime-linux-amd64.o" >&2
  exit 1
fi

cp -R "${ROOT_DIR}/stdlib/." "${STDLIB_DIR}/"

# Legacy path: pinned seed binary still probes ~/.local/share/di/runtime/runtime.o
LEGACY_DI_SHARE="${HOME}/.local/share/di"
mkdir -p "${LEGACY_DI_SHARE}/runtime"
cp "${RUNTIME_O}" "${LEGACY_DI_SHARE}/runtime/runtime.o"

if [ ! -f "${SEED}" ]; then
  echo "Missing ${SEED}; cannot install." >&2
  exit 1
fi
cp "${SEED}" "${BOOTSTRAP_DIR}/diva-linux-amd64"
chmod +x "${BOOTSTRAP_DIR}/diva-linux-amd64"

BUILD_LOG="${DIVA_SHARE}/.compiler-build.log"
DRIVER_INSTALLED=0
if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
  "${SEED}" build "${ROOT_DIR}/compiler" >"${BUILD_LOG}" 2>&1
then
  DRIVER=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD_LOG}" | tail -n 1)
  if [ -n "${DRIVER}" ] && [ -x "${DRIVER}" ]; then
    cp "${DRIVER}" "${LIBEXEC_DIR}/diva-driver"
    chmod +x "${LIBEXEC_DIR}/diva-driver"
    DRIVER_INSTALLED=1
  fi
fi

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
  ln -sf diva "${INSTALL_DIR}/di" 2>/dev/null || true
else
  sed -n '1,120p' "${BUILD_LOG}" >&2 || true
  echo "Warning: Diva compiler package did not build; installing seed binary as diva (no diva lex)." >&2
  cp "${BOOTSTRAP_DIR}/diva-linux-amd64" "${INSTALL_DIR}/diva"
  chmod +x "${INSTALL_DIR}/diva"
  ln -sf diva "${INSTALL_DIR}/di" 2>/dev/null || true
fi

echo "Installed diva to ${INSTALL_DIR}/diva (and di -> diva when supported)"
echo "Installed runtime object to ${RUNTIME_O}"
echo "Installed stdlib to ${STDLIB_DIR}"
echo "Installed bootstrap seed to ${BOOTSTRAP_DIR}/diva-linux-amd64"
if [ "${DRIVER_INSTALLED}" = "1" ]; then
  echo "Installed Diva-authored driver to ${LIBEXEC_DIR}/diva-driver (lexer + seed forward)"
fi
echo ""
echo "Add to your environment (e.g. ~/.profile):"
echo "  export PATH=\"${INSTALL_DIR}:\${PATH}\""
echo "  export DI_STDLIB_DIR=\"${STDLIB_DIR}\""
echo "  export DI_RUNTIME_O=\"${RUNTIME_O}\""
echo ""
echo "DIVA_BOOTSTRAP / DI_BOOTSTRAP are set by the diva wrapper to \${XDG_DATA_HOME:-\$HOME/.local/share}/diva/bootstrap/diva-linux-amd64"
echo "Linking user programs still uses the system linker driver (cc); there are no C sources in this repository."
