$ErrorActionPreference = "Stop"

$classesRoot = "HKCU:\Software\Classes"
$extensionKey = Join-Path $classesRoot ".diva"
$typeKey = Join-Path $classesRoot "Di.Source"
$commandKey = Join-Path $typeKey "shell\open\command"
$iconKey = Join-Path $typeKey "DefaultIcon"
$diriBin = Join-Path $HOME ".di\bin\di.exe"

if (-not (Test-Path $diriBin)) {
    throw "Di compiler not found at $diriBin. Run scripts/install.ps1 first."
}

New-Item -Path $extensionKey -Force | Out-Null
New-ItemProperty -Path $extensionKey -Name "(default)" -Value "Di.Source" -Force | Out-Null

New-Item -Path $typeKey -Force | Out-Null
New-ItemProperty -Path $typeKey -Name "(default)" -Value "Di Source File" -Force | Out-Null

New-Item -Path $iconKey -Force | Out-Null
New-ItemProperty -Path $iconKey -Name "(default)" -Value $diriBin -Force | Out-Null

New-Item -Path $commandKey -Force | Out-Null
New-ItemProperty -Path $commandKey -Name "(default)" -Value "`"$diriBin`" run `"%1`"" -Force | Out-Null

Write-Host "Installed Di file type association for .diva"
Write-Host "Registered .diva as Di Source File"
