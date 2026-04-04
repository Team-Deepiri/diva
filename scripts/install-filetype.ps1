$ErrorActionPreference = "Stop"

$classesRoot = "HKCU:\Software\Classes"
$extensionKey = Join-Path $classesRoot ".diva"
$typeKey = Join-Path $classesRoot "Diva.Source"
$commandKey = Join-Path $typeKey "shell\open\command"
$iconKey = Join-Path $typeKey "DefaultIcon"
$divaBin = Join-Path $HOME ".diva\bin\diva.exe"

if (-not (Test-Path $divaBin)) {
    throw "Diva compiler not found at $divaBin. Run scripts/install.ps1 first."
}

New-Item -Path $extensionKey -Force | Out-Null
New-ItemProperty -Path $extensionKey -Name "(default)" -Value "Diva.Source" -Force | Out-Null

New-Item -Path $typeKey -Force | Out-Null
New-ItemProperty -Path $typeKey -Name "(default)" -Value "Diva Source File" -Force | Out-Null

New-Item -Path $iconKey -Force | Out-Null
New-ItemProperty -Path $iconKey -Name "(default)" -Value $divaBin -Force | Out-Null

New-Item -Path $commandKey -Force | Out-Null
New-ItemProperty -Path $commandKey -Name "(default)" -Value "`"$divaBin`" run `"%1`"" -Force | Out-Null

Write-Host "Installed Diva file type association for .diva"
Write-Host "Registered .diva as Diva Source File"
