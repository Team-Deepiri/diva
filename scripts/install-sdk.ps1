$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$extensionTarget = if ($args.Length -gt 0) { $args[0] } else { Join-Path $HOME ".cursor\extensions" }

& (Join-Path $root "scripts\install.ps1")
& (Join-Path $root "scripts\install-filetype.ps1")
& (Join-Path $root "scripts\install-extension.ps1") $extensionTarget

Write-Host ""
Write-Host "Diva SDK install complete."
Write-Host "Compiler installed. Extension target: $extensionTarget"
Write-Host "File type registered: .diva"
Write-Host ""
Write-Host "Quickstart:"
Write-Host "  diva new hello-diva"
Write-Host "  cd hello-diva"
Write-Host "  diva run ."
