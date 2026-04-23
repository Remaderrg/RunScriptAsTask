param(
  [switch]$Install,
  [switch]$CI,
  [string]$OutDir = "."
)

$ErrorActionPreference = 'Stop'

function Invoke-Step([string]$FilePath, [string[]]$Args) {
  $pretty = ($Args | ForEach-Object {
    if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
  }) -join ' '
  Write-Host ">> $FilePath $pretty"
  & $FilePath @Args
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE"
  }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Invoke-CmdStep([string]$CommandLine) {
  Write-Host ">> $CommandLine"
  cmd /d /s /c $CommandLine
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code $LASTEXITCODE"
  }
}

if ($CI) {
  Invoke-CmdStep "npm ci"
} elseif ($Install) {
  Invoke-CmdStep "npm install"
}

Invoke-CmdStep "npm run compile"

if (Test-Path -LiteralPath (Join-Path $repoRoot "out\extension.js")) {
  $outFile = Get-Item -LiteralPath (Join-Path $repoRoot "out\extension.js")
  Write-Host "OK: built $($outFile.FullName) ($($outFile.Length) bytes)"
}

$outDirFull = (Resolve-Path -LiteralPath (Join-Path $repoRoot $OutDir)).Path
if (-not (Test-Path -LiteralPath $outDirFull)) {
  New-Item -ItemType Directory -Path $outDirFull | Out-Null
}

Invoke-CmdStep ("npx vsce package --out `"$outDirFull`"")

$vsix = Get-ChildItem -Path $outDirFull -Filter *.vsix -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($vsix) {
  Write-Host "OK: packaged $($vsix.FullName) ($([Math]::Round($vsix.Length / 1KB)) KB)"
} else {
  throw "Packaging finished but no .vsix found in: $outDirFull"
}

