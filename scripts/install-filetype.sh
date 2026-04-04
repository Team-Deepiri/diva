#!/usr/bin/env sh
set -eu

MIME_DIR="${HOME}/.local/share/mime/packages"
APP_DIR="${HOME}/.local/share/applications"
MIME_FILE="${MIME_DIR}/diva.xml"
DESKTOP_FILE="${APP_DIR}/diva.desktop"
DIVA_BIN="${HOME}/.local/bin/diva"

mkdir -p "${MIME_DIR}" "${APP_DIR}"

cat >"${MIME_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="text/x-diva">
    <comment>Diva source file</comment>
    <glob pattern="*.diva"/>
  </mime-type>
</mime-info>
EOF

cat >"${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=Diva
Comment=Run Diva source files
Exec=sh -lc '"${DIVA_BIN}" run "%f"; printf "\\nPress Enter to close..."; read _'
MimeType=text/x-diva;
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
    xdg-mime default diva.desktop text/x-diva || true
fi

echo "Installed Diva file type association for .diva"
echo "MIME type: text/x-diva"
