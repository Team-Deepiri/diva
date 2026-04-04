# Di Extension

This extension registers the `Di` language for `.diva` files.

Included today:

- `.diva` file association
- comment and bracket configuration
- syntax highlighting for the current language surface
- starter snippets for new files and common control flow

## Local Install

You can install it locally by copying this folder into your editor extensions directory, or by using the repository install scripts.

VS Code example:

- Linux: `~/.vscode/extensions/diri-lang`
- Windows: `%USERPROFILE%\\.vscode\\extensions\\diri-lang`

Cursor example:

- Linux: `~/.cursor/extensions/diri-lang`
- Windows: `%USERPROFILE%\\.cursor\\extensions\\diri-lang`

## Covered Syntax

The current grammar highlights:

- `func`, `extern`, `class`, `var`, `if`, `else`, `while`, `flux`, `in`, `return`, `true`, `false`, `package`, `import`
- primitive types like `int`, `bool`, `str`, `void`
- function calls
- field access via `.`
- array indexing with `[]`
- string and integer literals
- arithmetic, assignment, and comparison operators

## Scripted Install

From the repository root:

- Linux / WSL: `./scripts/install-extension.sh`
- PowerShell: `./scripts/install-extension.ps1`
