param(
  [string]$Tag,

  [string]$VsixPath,

  [string]$OutDir = ".",

  [switch]$Clobber
)

$ErrorActionPreference = 'Stop'

# PowerShell 7+ can treat native stderr / non-zero exit as terminating.
$PSNativeCommandUseErrorActionPreference = $false

function Invoke-CmdStep([string]$CommandLine) {
  Write-Host ">> $CommandLine"
  cmd /d /s /c $CommandLine
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE"
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "GitHub CLI ('gh') not found. Install it, then run: gh auth login"
}

if ([string]::IsNullOrWhiteSpace($Tag)) {
  $pkgPath = Join-Path $repoRoot "package.json"
  if (-not (Test-Path -LiteralPath $pkgPath)) {
    throw "package.json not found at: $pkgPath"
  }

  $pkg = Get-Content -LiteralPath $pkgPath -Raw | ConvertFrom-Json
  if (-not $pkg.version) {
    throw "package.json has no 'version' field"
  }

  $Tag = "v$($pkg.version)"
  Write-Host "Auto tag: $Tag"
}

# Ensure the release exists (create if missing).
# NOTE: gh prints "release not found" to stderr, which PowerShell treats as an error record.
$releaseExists = $false
try {
  & gh release view $Tag *> $null
} catch {
  # ignore; we'll decide based on exit code
}
if ($LASTEXITCODE -eq 0) {
  $releaseExists = $true
}

if (-not $releaseExists) {
  Write-Host "Release '$Tag' not found. Creating it."
  Invoke-CmdStep ("gh release create `"$Tag`" --title `"$Tag`" --notes `"$Tag`"")
}

if ([string]::IsNullOrWhiteSpace($VsixPath)) {
  # Build/package a fresh VSIX, then pick the newest from OutDir.
  $compileScript = Join-Path $repoRoot "scripts\compile.ps1"
  if (Test-Path -LiteralPath $compileScript) {
    Write-Host "No -VsixPath provided. Building VSIX via scripts/compile.ps1."
    & powershell -ExecutionPolicy Bypass -File $compileScript -OutDir $OutDir
    if ($LASTEXITCODE -ne 0) { throw "compile.ps1 failed with exit code $LASTEXITCODE" }
  } else {
    throw "No -VsixPath provided and compile script not found at: $compileScript"
  }

  $outDirFull = (Resolve-Path -LiteralPath (Join-Path $repoRoot $OutDir)).Path
  $latestVsix = Get-ChildItem -Path $outDirFull -Filter *.vsix -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if (-not $latestVsix) { throw "No .vsix found in: $outDirFull" }
  $VsixPath = $latestVsix.FullName
}

if (-not (Test-Path -LiteralPath $VsixPath)) {
  throw "VSIX not found at path: $VsixPath"
}

$vsixName = Split-Path -Leaf $VsixPath
if (-not $Clobber) {
  $assetNamesRaw = ""
  try {
    $assetNamesRaw = & gh release view $Tag --json assets --jq ".assets[].name" 2>$null
  } catch {
    $assetNamesRaw = ""
  }

  $assetNames = @()
  if ($assetNamesRaw) {
    $assetNames = $assetNamesRaw -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
  }

  if ($assetNames -contains $vsixName) {
    throw "Release '$Tag' already contains asset '$vsixName'. Refusing to upload the same version again. Use -Clobber to overwrite."
  }
}

$clobberArg = if ($Clobber) { "--clobber" } else { "" }
Invoke-CmdStep ("gh release upload `"$Tag`" `"$VsixPath`" $clobberArg")

