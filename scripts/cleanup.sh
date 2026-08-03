#!/usr/bin/env bash
# Compatibility wrapper — prefer cleanup-dev-artifacts.sh
exec "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/cleanup-dev-artifacts.sh" "$@"
