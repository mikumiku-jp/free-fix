$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/mikumiku-jp/free-fix.git"
$InstallDir = Join-Path $HOME "free-fix"
$LinkDir = Join-Path $HOME ".local\bin"
$BunMinVersion = [Version]"1.3.11"

function Write-Info($Message) {
  Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Write-Ok($Message) {
  Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warn($Message) {
  Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Fail($Message) {
  Write-Host "[x] $Message" -ForegroundColor Red
  exit 1
}

function Get-CommandVersion($CommandName) {
  try {
    $output = & $CommandName --version 2>$null
    if (-not $output) { return $null }
    $match = [regex]::Match(($output | Select-Object -First 1), '\d+(\.\d+)+')
    if (-not $match.Success) { return $null }
    return [Version]$match.Value
  } catch {
    return $null
  }
}

function Ensure-Git {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Ok "git: $((git --version | Select-Object -First 1))"
    return
  }

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Info "git not found. Installing with winget..."
    winget install --id Git.Git --accept-package-agreements --accept-source-agreements --silent
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
  }

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "git is not installed. Install Git for Windows, then rerun this script."
  }

  Write-Ok "git: $((git --version | Select-Object -First 1))"
}

function Ensure-Bun {
  $bunVersion = Get-CommandVersion "bun"
  if ($bunVersion -and $bunVersion -ge $BunMinVersion) {
    Write-Ok "bun: v$bunVersion"
    return
  }

  if ($bunVersion) {
    Write-Warn "bun v$bunVersion found but v$BunMinVersion or newer is required. Upgrading..."
  } else {
    Write-Info "bun not found. Installing..."
  }

  powershell -c "irm bun.sh/install.ps1 | iex"

  $bunBin = Join-Path $HOME ".bun\bin"
  if (Test-Path $bunBin) {
    $env:Path = "$bunBin;$env:Path"
  }

  $bunVersion = Get-CommandVersion "bun"
  if (-not $bunVersion) {
    Fail "bun installation completed but bun is still not on PATH. Add $bunBin to PATH and rerun."
  }

  Write-Ok "bun: v$bunVersion"
}

function Sync-Repo {
  if (Test-Path (Join-Path $InstallDir ".git")) {
    Write-Info "Updating existing repository..."
    git -C $InstallDir pull --ff-only origin main
  } elseif (Test-Path $InstallDir) {
    Write-Warn "$InstallDir already exists and is not a git repository. Reusing it."
  } else {
    Write-Info "Cloning repository..."
    git clone --depth 1 $RepoUrl $InstallDir
  }

  Write-Ok "Source: $InstallDir"
}

function Install-Deps {
  Write-Info "Installing dependencies..."
  Push-Location $InstallDir
  try {
    bun install --frozen-lockfile
  } catch {
    bun install
  } finally {
    Pop-Location
  }
  Write-Ok "Dependencies installed"
}

function Ensure-UserPath($PathToAdd) {
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  $entries = @()
  if ($userPath) {
    $entries = $userPath.Split(';') | Where-Object { $_ -ne "" }
  }

  if ($entries -contains $PathToAdd) {
    return
  }

  $newPath = if ($userPath) { "$userPath;$PathToAdd" } else { $PathToAdd }
  [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  $env:Path = "$PathToAdd;$env:Path"
  Write-Warn "$PathToAdd was added to your user PATH. Restart your terminal if commands are not found immediately."
}

function Write-Launcher($CommandName) {
  New-Item -ItemType Directory -Force -Path $LinkDir | Out-Null

  $launcherPath = Join-Path $LinkDir "$CommandName.cmd"
  $entrypoint = Join-Path $InstallDir "src\entrypoints\cli.tsx"
  $launcher = @"
@echo off
bun "$entrypoint" %*
"@

  Set-Content -Path $launcherPath -Value $launcher -Encoding ASCII
  Write-Ok "Installed: $launcherPath"
}

Write-Host ""
Write-Host "free-fix Windows installer" -ForegroundColor Cyan
Write-Host ""

Ensure-Git
Ensure-Bun
Sync-Repo
Install-Deps
Write-Info "Installing Bun-based launchers..."
Write-Launcher "free-fix"
Write-Launcher "free-code"
Ensure-UserPath $LinkDir

Write-Host ""
Write-Host "Installation complete." -ForegroundColor Green
Write-Host ""
Write-Host "Run:" -ForegroundColor White
Write-Host "  free-fix" -ForegroundColor Cyan
Write-Host "  free-code" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then authenticate with /login." -ForegroundColor White
Write-Host ""
