[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GodotPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot executable does not exist: $GodotPath"
}
$resolvedGodot = (Resolve-Path -LiteralPath $GodotPath).Path

$ordinaryTests = @(
	'gameplay_pace_test.gd',
	'prediction_scheduler_test.gd',
	'target_surface_coverage_test.gd',
	'coverage_publication_test.gd',
	'fixed_mountain_catalog_test.gd',
    'stage_generation_test.gd',
    'stage30_progression_test.gd',
	'generation_v10_materialization_test.gd',
    'baked_stage_layout_test.gd',
    'stage_layout_repository_test.gd',
	'stage_runtime_preparer_test.gd',
	'prepared_gameplay_entry_test.gd',
	'gameplay_first_use_warmup_test.gd',
	'stage_selection_readiness_test.gd',
    'play_bounds_test.gd',
    'open_play_environment_test.gd',
    'terrain_surface_paint_scope_test.gd',
    'stage_cannon_standoff_test.gd',
    'mechanism_placement_test.gd',
    'glyph_aim_view_composition_test.gd',
    'decoration_placement_test.gd',
    'stage2_burst_glyph_contract_test.gd',
    'stage3_glyph_route_contract_test.gd',
    'stage8_uphill_glyph_contract_test.gd',
    'projectile_contact_test.gd',
    'projectile_settling_test.gd',
    'phase3_paint_test.gd',
    'paint_queue_determinism_test.gd',
    'phase3_projectile_paint_test.gd',
    'phase4_state_test.gd',
    'phase5_mechanism_test.gd',
	'phase6_content_test.gd',
	'terrain_aim_solver_test.gd',
	'aim_interaction_test.gd',
	'stage10_prediction_readiness_test.gd',
    'shot_observation_test.gd',
    'camera_safety_test.gd',
	'map_inspection_direction_test.gd',
    'phase8_aiming_composition_test.gd',
    'trajectory_preview_efficiency_test.gd',
    'shot_follow_camera_test.gd',
    'phase7_ui_test.gd',
    'phase7_user_qa_contract_test.gd',
    'phase8_hud_truth_test.gd',
    'localization_ui_test.gd',
	'shot_feedback_test.gd',
	'shortcut_prompt_test.gd',
	'phase8_debug_test.gd'
)

function Invoke-GodotTest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        [string[]]$EngineArguments = @(),
        [string[]]$UserArguments = @()
    )

    Write-Host "Running $ScriptName..."
	$arguments = @(
		'--headless', '--path', $projectRoot, '--quit-after', '7200'
	) + $EngineArguments + @('--script', "res://tests/$ScriptName")
    if ($UserArguments.Count -gt 0) {
        $arguments += '--'
        $arguments += $UserArguments
    }
	$output = & $resolvedGodot @arguments 2>&1
	$exitCode = $LASTEXITCODE
	$output | ForEach-Object { Write-Host $_ }
	$text = $output | Out-String
	if ($exitCode -ne 0) {
		throw "$ScriptName failed with exit code $exitCode."
	}
	if ($text -match '(?m)^(SCRIPT ERROR|ERROR):') {
		throw "$ScriptName reported a Godot script or runtime error."
	}
}

$primaryFailure = $null
try {
    foreach ($test in $ordinaryTests) {
        Invoke-GodotTest -ScriptName $test
    }

    Invoke-GodotTest -ScriptName 'phase8_persistence_test.gd' -UserArguments @('--mode=cleanup')
    Invoke-GodotTest -ScriptName 'phase8_persistence_test.gd' -UserArguments @('--mode=write')
    Invoke-GodotTest -ScriptName 'phase8_persistence_test.gd' -UserArguments @('--mode=read')
}
catch {
    $primaryFailure = $_
}
finally {
    $cleanupFailures = [System.Collections.Generic.List[string]]::new()
	foreach ($cleanup in @(
		@{ Script = 'phase8_persistence_test.gd'; Mode = '--mode=cleanup' }
	)) {
        try {
            Invoke-GodotTest -ScriptName $cleanup.Script -UserArguments @($cleanup.Mode)
        }
        catch {
            $cleanupFailures.Add($_.Exception.Message)
        }
    }
    if ($cleanupFailures.Count -gt 0) {
        $cleanupMessage = 'Final cleanup failed: ' + ($cleanupFailures -join ' | ')
        if ($null -eq $primaryFailure) {
            $primaryFailure = [System.Management.Automation.RuntimeException]::new($cleanupMessage)
        }
        else {
            Write-Error $cleanupMessage
        }
    }
}

if ($null -ne $primaryFailure) {
    throw $primaryFailure
}
Write-Host 'Paint Mountain complete test suite passed.'
