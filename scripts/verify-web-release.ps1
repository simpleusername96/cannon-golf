[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseDirectory,
    [long]$BaselineGzipBytes = 17269724
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# This is the accepted gzip total of the Web artifact produced before Phase 4.
# Keep the value explicit: a CI run must never silently establish its own budget.
[long]$MaxInitialPayloadGzipBytes = 20MB
[int]$MaxItchFileCount = 1000
[long]$MaxItchExtractedBytes = 500MB
[long]$MaxItchFileBytes = 200MB
[int]$MaxItchPathLength = 240

function Get-GzipLength {
    param([Parameter(Mandatory = $true)][string]$Path)

    $input = [System.IO.File]::OpenRead($Path)
    $output = [System.IO.MemoryStream]::new()
    $gzip = [System.IO.Compression.GzipStream]::new(
        $output,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $true
    )
    try {
        $input.CopyTo($gzip)
    }
    finally {
        $gzip.Dispose()
        $input.Dispose()
    }
    try {
        return $output.Length
    }
    finally {
        $output.Dispose()
    }
}

function Get-LocalReference {
    param([Parameter(Mandatory = $true)][string]$Value)

    $reference = [System.Uri]::UnescapeDataString($Value.Split('#', 2)[0].Split('?', 2)[0])
    if ([string]::IsNullOrWhiteSpace($reference) -or $reference -match '^(?i:data:|https?:|//)') {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($reference) -or $reference -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Web reference must remain inside the release directory: $Value"
    }
    return $reference.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Assert-ExactArtifactPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Reference
    )

    $candidate = $Root
    foreach ($segment in $Reference -split '[\\/]') {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.') {
            continue
        }
        $matches = @(Get-ChildItem -LiteralPath $candidate -Force | Where-Object { $_.Name -ceq $segment })
        if ($matches.Count -ne 1) {
            throw "Web artifact is missing the exact-case runtime reference: $Reference"
        }
        $candidate = $matches[0].FullName
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Web runtime reference is not a file: $Reference"
    }
    return $candidate
}

$releaseRoot = (Resolve-Path -LiteralPath $ReleaseDirectory -ErrorAction Stop).Path
$indexPath = Join-Path $releaseRoot 'index.html'
$scriptPath = Join-Path $releaseRoot 'index.js'
foreach ($required in @($indexPath, $scriptPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Web release is missing $required."
    }
}

$html = Get-Content -LiteralPath $indexPath -Raw
$script = Get-Content -LiteralPath $scriptPath -Raw
$references = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

# HTML resource attributes are literal. Do not inspect arbitrary JavaScript strings:
# generated Emscripten contains documentation/error text that is not a file reference.
foreach ($match in [regex]::Matches($html, '(?is)\b(?:src|href)\s*=\s*["''](?<value>[^"'']+)["'']')) {
    $localReference = Get-LocalReference -Value $match.Groups['value'].Value
    if ($null -ne $localReference) {
        [void]$references.Add($localReference)
    }
}

$configMatch = [regex]::Match($html, '(?s)const\s+GODOT_CONFIG\s*=\s*(?<json>\{.*?\});')
if (-not $configMatch.Success) {
    throw 'Web index.html does not contain a GODOT_CONFIG object.'
}
$config = $configMatch.Groups['json'].Value | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$config.executable)) {
    throw 'Web GODOT_CONFIG does not declare an executable name.'
}
foreach ($fileName in $config.fileSizes.PSObject.Properties.Name) {
    [void]$references.Add((Get-LocalReference -Value $fileName))
}
foreach ($library in @($config.gdextensionLibs)) {
    [void]$references.Add((Get-LocalReference -Value ([string]$library)))
}

$executable = [string]$config.executable
[void]$references.Add("$executable.wasm")
[void]$references.Add("$executable.pck")
if ($script -match [regex]::Escape('.audio.worklet.js')) {
    [void]$references.Add("$executable.audio.worklet.js")
}
if ($script -match [regex]::Escape('.audio.position.worklet.js')) {
    [void]$references.Add("$executable.audio.position.worklet.js")
}

foreach ($reference in $references) {
    [void](Assert-ExactArtifactPath -Root $releaseRoot -Reference $reference)
}

if ($html -notmatch 'const\s+GODOT_THREADS_ENABLED\s*=\s*false\s*;') {
    throw 'Web index.html does not declare the required no-thread runtime contract.'
}
$threadArtifacts = @(Get-ChildItem -LiteralPath $releaseRoot -Recurse -File | Where-Object {
    $_.Name -match '(?i)(pthread|\.worker\.js$|\.threads?\.)'
})
if ($threadArtifacts.Count -gt 0) {
    throw "Web release contains thread-enabled artifacts: $($threadArtifacts.Name -join ', ')"
}

$files = @(Get-ChildItem -LiteralPath $releaseRoot -Recurse -File)
if ($files.Count -gt $MaxItchFileCount) {
    throw "Web release contains $($files.Count) files; itch.io allows at most $MaxItchFileCount."
}
$totalRawBytes = [long](($files | Measure-Object -Property Length -Sum).Sum)
if ($totalRawBytes -gt $MaxItchExtractedBytes) {
    throw "Web release is $totalRawBytes bytes; itch.io allows at most $MaxItchExtractedBytes extracted bytes."
}
foreach ($file in $files) {
    $relativePath = [System.IO.Path]::GetRelativePath($releaseRoot, $file.FullName).Replace('\', '/')
    if ($file.Length -gt $MaxItchFileBytes) {
        throw "Web release contains a file larger than itch.io's $MaxItchFileBytes-byte limit: $relativePath"
    }
    if ($relativePath.Length -gt $MaxItchPathLength) {
        throw "Web release path exceeds itch.io's $MaxItchPathLength-character limit: $relativePath"
    }
}

$gzipByPath = @{}
foreach ($file in $files) {
    $gzipByPath[$file.FullName] = Get-GzipLength -Path $file.FullName
}
$totalGzipBytes = [long](($gzipByPath.Values | Measure-Object -Sum).Sum)
$allowedBaselineGzipBytes = [long][Math]::Floor($BaselineGzipBytes * 1.10)
if ($totalGzipBytes -gt $MaxInitialPayloadGzipBytes) {
    throw "Web gzip payload is $totalGzipBytes bytes; the initial payload limit is $MaxInitialPayloadGzipBytes bytes."
}
if ($totalGzipBytes -gt $allowedBaselineGzipBytes) {
    throw "Web gzip payload is $totalGzipBytes bytes; it exceeds the explicit 10% baseline allowance of $allowedBaselineGzipBytes bytes (baseline $BaselineGzipBytes)."
}

Write-Host "Web references verified: $($references.Count) exact-case files."
foreach ($name in @('index.wasm', 'index.pck', 'index.js')) {
    $path = Assert-ExactArtifactPath -Root $releaseRoot -Reference $name
    Write-Host ('{0}: raw={1} gzip={2}' -f $name, (Get-Item -LiteralPath $path).Length, $gzipByPath[$path])
}
Write-Host "Web artifact summary: files=$($files.Count) raw=$totalRawBytes gzip=$totalGzipBytes baseline=$BaselineGzipBytes allowance=$allowedBaselineGzipBytes"
Write-Host 'Web release static verification passed.'
