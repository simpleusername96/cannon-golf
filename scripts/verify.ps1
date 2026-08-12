[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_BIN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sharedGodot = 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'

$requestedGodotExists = -not [string]::IsNullOrWhiteSpace($GodotPath) `
    -and (Test-Path -LiteralPath $GodotPath -PathType Leaf)
if (-not $requestedGodotExists -and (Test-Path -LiteralPath $sharedGodot -PathType Leaf)) {
    $GodotPath = $sharedGodot
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $command = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) {
        $GodotPath = $command.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot was not found at D:\tools\Godot\4.7.1-stable. Pass -GodotPath, set GODOT_BIN, or add godot4/godot to PATH.'
}

$resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path

function Invoke-GodotCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [switch]$AllowReportedErrors
    )

    $output = & $resolvedGodot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    $text = $output | Out-String
    if ($exitCode -ne 0) {
        throw "$Label failed with exit code $exitCode."
    }
    if (-not $AllowReportedErrors -and $text -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw "$Label reported a Godot script or runtime error."
    }
}

Write-Host 'Importing project assets...'
Invoke-GodotCheck -Label 'Godot asset import' -AllowReportedErrors -Arguments @(
    '--headless', '--path', $projectRoot, '--import'
)

Write-Host 'Checking project import and script parsing...'
Invoke-GodotCheck -Label 'Godot editor smoke check' -Arguments @(
    '--headless', '--path', $projectRoot, '--editor', '--quit'
)

Write-Host 'Checking main-scene startup...'
Invoke-GodotCheck -Label 'Godot runtime smoke check' -Arguments @(
    '--headless', '--path', $projectRoot, '--quit-after', '3'
)

Write-Host 'Paint Mountain verification passed.'
