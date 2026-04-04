$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$extSource = Join-Path $root "tools\vscode-extension"

if ($args.Length -gt 0) {
    $targetRoot = $args[0]
} else {
    $targetRoot = Join-Path $HOME ".cursor\extensions"
}

$targetDir = Join-Path $targetRoot "diva-lang"

New-Item -ItemType Directory -Force $targetRoot | Out-Null
if (Test-Path $targetDir) {
    Remove-Item -Recurse -Force $targetDir
}
Copy-Item -Recurse -Force $extSource $targetDir

Write-Host "Installed Diva editor extension to $targetDir"
Write-Host "For VS Code, run:"
Write-Host "  ./scripts/install-extension.ps1 `"$HOME\.vscode\extensions`""
