$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$installDir = Join-Path $HOME ".di\bin"
$output = Join-Path $installDir "di.exe"
$runtimeDir = Join-Path $HOME ".di\runtime"
$runtimeSource = Join-Path $runtimeDir "runtime.c"
$stdlibDir = Join-Path $HOME ".di\stdlib"

New-Item -ItemType Directory -Force $installDir | Out-Null
New-Item -ItemType Directory -Force $runtimeDir | Out-Null
New-Item -ItemType Directory -Force $stdlibDir | Out-Null
Copy-Item -Force (Join-Path $root "runtime\runtime.c") $runtimeSource
Copy-Item -Force -Recurse (Join-Path $root "stdlib\*") $stdlibDir

$sources = @(
    (Join-Path $root "src\main.c"),
    (Join-Path $root "src\driver.c"),
    (Join-Path $root "src\diag.c"),
    (Join-Path $root "src\token.c"),
    (Join-Path $root "src\lexer.c"),
    (Join-Path $root "src\ast.c"),
    (Join-Path $root "src\ir.c"),
    (Join-Path $root "src\parser.c"),
    (Join-Path $root "src\sema.c"),
    (Join-Path $root "src\codegen_llvm.c")
)

$includeDir = Join-Path $root "include"
$runtimeDefine = "/DDI_RUNTIME_SOURCE=`"$($runtimeSource -replace '\\','/')`""
$stdlibDefine = "/DDI_STDLIB_DIR=`"$($stdlibDir -replace '\\','/')`""

if (Get-Command cl -ErrorAction SilentlyContinue) {
    & cl /nologo /I $includeDir $runtimeDefine $stdlibDefine /Fe:$output $sources
} elseif (Get-Command gcc -ErrorAction SilentlyContinue) {
    & gcc -I $includeDir "-DDI_RUNTIME_SOURCE=`"$($runtimeSource -replace '\\','/')`"" "-DDI_STDLIB_DIR=`"$($stdlibDir -replace '\\','/')`"" $sources -o $output
} else {
    throw "No supported C compiler found. Install Visual Studio Build Tools or gcc/clang."
}

Write-Host "Installed di to $output"
Write-Host "Installed runtime to $runtimeSource"
Write-Host "Installed stdlib to $stdlibDir"
Write-Host "Add $installDir to your PATH if needed."
