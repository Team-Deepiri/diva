# Diva SDK layout (Issue #29)

Shipped SDK pieces after `./scripts/install-sdk.sh`:

| Path | Role |
|------|------|
| `~/.local/bin/diva` | Native driver (bootstrap seed or rebuilt pure ELF) |
| `stdlib/` | Standard library (`import "std/…"`) |
| `bootstrap/` | Seed compiler + `runtime-linux-amd64.o` (hosted link optional) |
| `.diva/cache/` | Package merge cache (see Issue #24) |
| `docs/` | Language spec, stdlib map, install guide |

## Project templates (`diva new`)

| Flag | `kind` | Entry | Use |
|------|--------|-------|-----|
| *(default)* | `app` | `src/main.diva` | Hosted CLI / tools |
| `--lib` | `lib` | `src/lib.diva` | Reusable package |
| `--kernel` | `kernel` | `src/boot.diva` | `kmain` bring-up (#59) |
| `--system` | `system` | `src/system.diva` | Freestanding / syscall-first (#30) |

Each template writes `package.diva`, `src/`, `.gitignore`, and `README.md`.

## Release packaging

`scripts/package-release.sh [version]` builds `diva-sdk-<version>.tar.gz` containing
bootstrap, stdlib, compiler sources, install scripts, and this layout doc — suitable
for offline installs without cloning the full git history.

## Editor support

`scripts/install-extension.sh` installs Cursor/VS Code syntax highlighting for `.diva`.
Diagnostics and LSP remain future work (roadmap Phase 7).
