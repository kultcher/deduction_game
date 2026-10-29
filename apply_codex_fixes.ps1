$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoRoot

$PatchFile = Join-Path $RepoRoot 'codex_review_fixes.patch'
if (-not (Test-Path $PatchFile)) {
    throw "Patch file not found: $PatchFile"
}

Write-Host "==> Applying patch 'codex_review_fixes.patch'..." -ForegroundColor Cyan
$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& git apply --ignore-whitespace --whitespace=nowarn $PatchFile | Out-Host
$applyCode = $LASTEXITCODE
$ErrorActionPreference = $prevPref

if ($applyCode -ne 0) {
    Write-Host "==> Retrying git apply with --3way..." -ForegroundColor Yellow
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & git apply --3way --ignore-whitespace --whitespace=nowarn $PatchFile | Out-Host
    $threeWayCode = $LASTEXITCODE
    $ErrorActionPreference = $prevPref
    if ($threeWayCode -ne 0) {
        throw "git apply failed (exit code $threeWayCode)."
    }
}

Write-Host "==> Patch applied cleanly! Modified files:" -ForegroundColor Green
$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& git status -s -- sim game workshop ui tools | Out-Host
$ErrorActionPreference = $prevPref
