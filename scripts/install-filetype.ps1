$ErrorActionPreference = "Stop"

$classesRoot = "HKCU:\Software\Classes"
$extensionKey = Join-Path $classesRoot ".di"
$typeKey = Join-Path $classesRoot "Diri.Source"
$commandKey = Join-Path $typeKey "shell\open\command"
$iconKey = Join-Path $typeKey "DefaultIcon"
$diriBin = Join-Path $HOME ".diri\bin\diri.exe"

if (-not (Test-Path $diriBin)) {
    throw "Diri compiler not found at $diriBin. Run scripts/install.ps1 first."
}

New-Item -Path $extensionKey -Force | Out-Null
New-ItemProperty -Path $extensionKey -Name "(default)" -Value "Diri.Source" -Force | Out-Null

New-Item -Path $typeKey -Force | Out-Null
New-ItemProperty -Path $typeKey -Name "(default)" -Value "Diri Source File" -Force | Out-Null

New-Item -Path $iconKey -Force | Out-Null
New-ItemProperty -Path $iconKey -Name "(default)" -Value $diriBin -Force | Out-Null

New-Item -Path $commandKey -Force | Out-Null
New-ItemProperty -Path $commandKey -Name "(default)" -Value "`"$diriBin`" run `"%1`"" -Force | Out-Null

Write-Host "Installed Diri file type association for .di"
Write-Host "Registered .di as Diri Source File"
