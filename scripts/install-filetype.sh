#!/usr/bin/env sh
set -eu

MIME_DIR="${HOME}/.local/share/mime/packages"
APP_DIR="${HOME}/.local/share/applications"
MIME_FILE="${MIME_DIR}/di.xml"
DESKTOP_FILE="${APP_DIR}/di.desktop"
DI_BIN="${HOME}/.local/bin/di"

mkdir -p "${MIME_DIR}" "${APP_DIR}"

cat >"${MIME_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="text/x-di">
    <comment>Di source file</comment>
    <glob pattern="*.di"/>
  </mime-type>
</mime-info>
EOF

cat >"${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Di
Comment=Run Di source files
Exec=sh -lc '"${DI_BIN}" run "%f"; printf "\\nPress Enter to close..."; read _'
MimeType=text/x-di;
Terminal=true
Categories=Development;
NoDisplay=true
EOF

if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database "${HOME}/.local/share/mime"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APP_DIR}" >/dev/null 2>&1 || true
fi

if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default di.desktop text/x-di || true
fi

echo "Installed Di file type association for .di"
echo "MIME type: text/x-di"
