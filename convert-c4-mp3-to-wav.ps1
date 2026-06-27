param(
    [Parameter(Mandatory = $true)]
    [string]$RootDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,

    [string]$FfmpegPath = "ffmpeg",

    [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RootDirectory -PathType Container)) {
    throw "Root directory does not exist: $RootDirectory"
}

if ($DestinationDirectory) {
    if (-not (Test-Path -LiteralPath $DestinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
        Write-Host "Created destination directory: $DestinationDirectory"
    }
}

$ffmpegCmd = Get-Command $FfmpegPath -ErrorAction SilentlyContinue
if (-not $ffmpegCmd) {
    throw "ffmpeg not found. Install ffmpeg or pass -FfmpegPath with the full executable path."
}

$files = Get-ChildItem -LiteralPath $RootDirectory -Recurse -File -Filter "*.mp3" |
    Where-Object { $_.BaseName -match "C4" }

if (-not $files) {
    Write-Host "No matching files found (.mp3 with 'C4' in filename)."
    exit 0
}

Write-Host "Found $($files.Count) matching file(s)."

$converted = 0
$skipped = 0
$failed = 0

foreach ($file in $files) {
    $instrument = $file.BaseName -replace '_.*', ''
    $wavName = "$instrument.wav"

    if ($DestinationDirectory) {
        $outputPath = Join-Path $DestinationDirectory $wavName
    }
    else {
        $outputPath = Join-Path $file.DirectoryName $wavName
    }

    if ((-not $Overwrite) -and (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        Write-Host "Skipping (exists): $outputPath"
        $skipped += 1
        continue
    }

    Write-Host "Converting: $($file.FullName) -> $outputPath"

    $args = @("-hide_banner", "-loglevel", "error")
    if ($Overwrite) {
        $args += "-y"
    }
    else {
        $args += "-n"
    }

    $args += @(
        "-i", $file.FullName,
        $outputPath
    )

    & $ffmpegCmd.Source @args
    if ($LASTEXITCODE -eq 0) {
        $converted += 1
    }
    else {
        Write-Warning "Conversion failed: $($file.FullName)"
        $failed += 1
    }
}

Write-Host "Done. Converted: $converted, Skipped: $skipped, Failed: $failed"
if ($failed -gt 0) {
    exit 1
}
