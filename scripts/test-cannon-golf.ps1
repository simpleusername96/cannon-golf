[CmdletBinding()]
param(
    [string]$GodotPath = $env:GODOT_BIN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sharedGodot = 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'
if ([string]::IsNullOrWhiteSpace($GodotPath) -and (Test-Path -LiteralPath $sharedGodot -PathType Leaf)) {
    $GodotPath = $sharedGodot
}
if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot 4.7.1 was not found. Pass -GodotPath or set GODOT_BIN.'
}
$resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$tests = @(
    'cannon_golf_course_test.gd',
	'cannon_golf_course_artifact_test.gd',
	'cannon_golf_course_repository_test.gd',
	'cannon_golf_course_selection_state_test.gd',
    'cannon_golf_ballistics_test.gd',
    'cannon_golf_live_ball_lifecycle_test.gd',
    'cannon_golf_range_test.gd',
    'cannon_golf_goal_test.gd',
    'cannon_golf_course_build_test.gd',
    'cannon_golf_world_environment_test.gd',
    'cannon_golf_camera_test.gd',
    'cannon_golf_performance_test.gd',
    'cannon_golf_terrain_test.gd',
    'cannon_golf_course_variety_test.gd',
    'cannon_golf_terrain_slope_test.gd',
    'cannon_golf_physics_test.gd',
    'cannon_golf_input_test.gd',
    'cannon_golf_session_test.gd',
    'cannon_golf_relay_test.gd',
	'cannon_golf_multi_goal_test.gd',
    'cannon_golf_solution_test.gd',
    'cannon_golf_ui_contract_test.gd',
    'cannon_golf_settings_test.gd',
    'cannon_golf_app_flow_test.gd'
)

foreach ($test in $tests) {
    Write-Host "Running $test..."
    $output = & (Join-Path $PSScriptRoot 'invoke-cannon-golf-validation.ps1') -GodotPath $resolvedGodot -Script "res://tests/$test" 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    $text = $output | Out-String
    if ($exitCode -ne 0) {
        throw "$test failed with exit code $exitCode."
    }
    if ($text -match '(?m)^(SCRIPT ERROR|ERROR):') {
        throw "$test reported a Godot script or runtime error."
    }
}

Write-Host 'Cannon Golf focused test suite passed.'
