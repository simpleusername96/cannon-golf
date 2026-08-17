[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Script,
    [string]$GodotPath = $env:GODOT_BIN,
    [string[]]$UserArgs = @(),
    [switch]$CheckOnly,
    [switch]$Rendered,
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runDirectory = Join-Path ([IO.Path]::GetTempPath()) ("cannon-golf-validation-" + [guid]::NewGuid())
$sharedGodot = 'D:\tools\Godot\4.7.1-stable\Godot_v4.7.1-stable_win64_console.exe'
if ([string]::IsNullOrWhiteSpace($GodotPath) -and (Test-Path -LiteralPath $sharedGodot -PathType Leaf)) {
    $GodotPath = $sharedGodot
}
if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw 'Godot 4.7.1 was not found. Pass -GodotPath or set GODOT_BIN.'
}
$authoringScripts = @(
    'res://scripts/bake_cannon_golf_courses.gd'
)
if (-not $Script.StartsWith('res://tests/') -and $Script -notin $authoringScripts `
        -and -not ($CheckOnly -and $Script.StartsWith('res://src/cannon_golf/'))) {
    throw 'The bounded validation wrapper accepts focused tests and approved Cannon Golf authoring scripts only.'
}
foreach ($argument in $UserArgs) {
    if ([string]::IsNullOrWhiteSpace($argument) -or -not $argument.StartsWith('--') `
            -or $argument.Contains('"') -or $argument.Contains("`r") -or $argument.Contains("`n")) {
        throw 'Every Godot user argument must be one non-empty --name or --name=value token.'
    }
}

$mutex = [Threading.Mutex]::new($false, 'Global\CannonGolfValidationSingleRun')
if (-not $mutex.WaitOne(0)) {
    [Console]::Error.WriteLine('Another heavyweight Cannon Golf validation run owns the single-run guard.')
    exit 20
}

function Get-DirectoryBytes([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return [int64]0 }
    return [int64](Get-ChildItem -LiteralPath $Path -File -Recurse -Force | Measure-Object -Property Length -Sum).Sum
}

function Get-FileLengths([string]$Path) {
    $lengths = @{}
    if (Test-Path -LiteralPath $Path) {
        foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse -Force) {
            $lengths[$file.FullName] = [int64]$file.Length
        }
    }
    return $lengths
}

function Restore-LogLengths([string]$Path, [hashtable]$Lengths) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    foreach ($file in Get-ChildItem -LiteralPath $Path -File -Recurse -Force) {
        if (-not $Lengths.ContainsKey($file.FullName)) {
            Remove-Item -LiteralPath $file.FullName -Force
        } elseif ([int64]$file.Length -gt [int64]$Lengths[$file.FullName]) {
            $stream = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Write)
            try { $stream.SetLength([int64]$Lengths[$file.FullName]) } finally { $stream.Dispose() }
        }
    }
}

function Stop-OwnedTree([Diagnostics.Process]$Process) {
    if ($null -eq $Process -or $Process.HasExited) { return }
    if ($IsWindows) {
        & "$env:SystemRoot\System32\taskkill.exe" /PID $Process.Id /T /F | Out-Null
    }
    else {
        $Process.Kill($true)
    }
    $Process.WaitForExit(5000) | Out-Null
}

try {
    $validationVolumeRoot = [IO.Path]::GetPathRoot($runDirectory)
    $validationVolume = [IO.DriveInfo]::new($validationVolumeRoot)
    $freeBefore = [int64]$validationVolume.AvailableFreeSpace
    if ($freeBefore -lt 10GB) {
        [Console]::Error.WriteLine("Validation volume free space is below the 10 GiB safety floor: $freeBefore bytes.")
        exit 21
    }
    $localDataRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $logDirectory = if ($IsWindows) {
        Join-Path $localDataRoot 'Godot\app_userdata\Cannon Golf Prototype\logs'
    }
    else {
        Join-Path $localDataRoot 'godot/app_userdata/Cannon Golf Prototype/logs'
    }
    $logBefore = Get-DirectoryBytes $logDirectory
	$logLengthsBefore = Get-FileLengths $logDirectory
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Resolve-Path -LiteralPath $GodotPath).Path
    New-Item -ItemType Directory -Path $runDirectory | Out-Null
    $runLogFile = Join-Path $runDirectory 'godot.log'
    # The wrapper's wall-clock deadline is authoritative. A frame-count quit
    # can silently end an accelerated headless physics run with exit code 0
    # before its coroutine reaches an explicit success/failure result.
    $checkOnlyArgument = if ($CheckOnly) { ' --check-only' } else { '' }
    $displayArgument = if ($Rendered) { '' } else { '--headless ' }
    $startInfo.Arguments = "$displayArgument--log-file `"$runLogFile`" --path `"$projectRoot`" --script `"$Script`"$checkOnlyArgument"
    if ($UserArgs.Count -gt 0) {
        $quotedUserArgs = $UserArgs | ForEach-Object { '"' + $_ + '"' }
        $startInfo.Arguments += ' -- ' + ($quotedUserArgs -join ' ')
    }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    if (-not $process.Start()) { throw 'Godot did not start.' }

    $outputCap = 4MB
    [int64]$outputBytes = 0
    $tail = [Collections.Generic.Queue[string]]::new()
    $failure = $null
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $outputTask = $process.StandardOutput.ReadLineAsync()
    $errorTask = $process.StandardError.ReadLineAsync()
    while (-not $process.HasExited) {
        foreach ($entry in @(@{ Task = $outputTask; Stream = 'stdout' }, @{ Task = $errorTask; Stream = 'stderr' })) {
            if (-not $entry.Task.IsCompleted) { continue }
            $line = $entry.Task.GetAwaiter().GetResult()
            if ($null -ne $line) {
                $outputBytes += [Text.Encoding]::UTF8.GetByteCount($line) + 2
                $tail.Enqueue("[$($entry.Stream)] $line")
                while ($tail.Count -gt 200) { $tail.Dequeue() }
                if ($outputBytes -gt $outputCap) { $failure = 'Captured output exceeded 4 MiB.' }
                elseif ($line -match 'SCRIPT ERROR:|(?<!SCRIPT )ERROR:') {
                    # Godot emits this generic preload line before the useful
                    # parser location. Let the process print the immediate root
                    # cause; the next error or nonzero exit still stops the run.
                    if ($line -notmatch 'Could not preload resource script') {
                        $failure = "Godot reported: $line"
                    }
                }
            }
            if ($entry.Stream -eq 'stdout') { $outputTask = $process.StandardOutput.ReadLineAsync() } else { $errorTask = $process.StandardError.ReadLineAsync() }
        }
        if ($null -ne $failure) { break }
        if ([DateTime]::UtcNow -ge $deadline) { $failure = "Wall-clock timeout after $TimeoutSeconds seconds."; break }
        Start-Sleep -Milliseconds 20
    }
    if ($null -ne $failure) { Stop-OwnedTree $process }
    $process.WaitForExit(5000) | Out-Null
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
	if (($null -ne $failure -or $exitCode -ne 0) -and (Test-Path -LiteralPath $runLogFile)) {
		foreach ($line in Get-Content -LiteralPath $runLogFile -Tail 200) {
			$tail.Enqueue("[godot-log] $line")
			while ($tail.Count -gt 200) { $tail.Dequeue() }
		}
	}
	Restore-LogLengths $logDirectory $logLengthsBefore
    $freeAfter = [int64]([IO.DriveInfo]::new($validationVolumeRoot).AvailableFreeSpace)
    $logAfter = Get-DirectoryBytes $logDirectory
    $logGrowth = $logAfter - $logBefore
    $ownedProcessCount = if ($process.HasExited) { 0 } else { 1 }
    Write-Host "validation evidence: exit=$exitCode volume_free_before=$freeBefore volume_free_after=$freeAfter log_before=$logBefore log_after=$logAfter log_growth=$logGrowth owned_processes=$ownedProcessCount"
    if ($logGrowth -gt 1MB) { $failure = "Godot user log growth exceeded 1 MiB: $logGrowth bytes." }
    if ($ownedProcessCount -ne 0) { $failure = 'Owned Godot process remained after cleanup.' }
    if ($null -eq $failure -and $exitCode -eq 0) {
		foreach ($line in $tail) { Write-Host $line }
		Remove-Item -LiteralPath $runDirectory -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host 'Cannon Golf bounded validation passed.'
        exit 0
    }
    if ($null -eq $failure) { $failure = "Godot exited with code $exitCode." }
	foreach ($line in $tail) { Write-Host $line }
	Remove-Item -LiteralPath $runDirectory -Recurse -Force -ErrorAction SilentlyContinue
    [Console]::Error.WriteLine($failure)
    if ($exitCode -ne 0) { exit $exitCode }
    exit 1
}
finally {
	Remove-Item -LiteralPath $runDirectory -Recurse -Force -ErrorAction SilentlyContinue
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
