<#
.SYNOPSIS
  Sync private Home Assistant repo → commit & push (current branch),
  then optionally mirror selected folders to public repo with same commit message.

.DESCRIPTION
  - Cross-platform (Windows + Linux/code-server).
  - Auto-detects paths; supports overrides via parameters or env vars.
  - Safe public sync: git pull --ff-only, abort if dirty before copying.

.PARAMETER HomeRoot
  Override private repo root (default auto-detect).

.PARAMETER PublicRoot
  Override public mirror repo root (default auto-detect).

.PARAMETER Message
  Provide commit message non-interactively (skips popup/prompt).

.EXAMPLES
  pwsh ./sync-ha-and-public.ps1
  pwsh ./sync-ha-and-public.ps1 -HomeRoot Z:\ -PublicRoot "C:\Git\homeassistant-public"
  pwsh ./sync-ha-and-public.ps1 -HomeRoot /mnt/homeassistant_config -PublicRoot "$HOME/homeassistant-public" -Message "Fix dashboards"
#>

[CmdletBinding()]
param(
  [string]$HomeRoot,
  [string]$PublicRoot,
  [string]$Message
)

function Resolve-FirstExisting {
  param([string[]]$Candidates)
  foreach ($c in $Candidates) { if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path } }
  return $null
}

# ---- Candidate paths (Windows + Linux/code-server) ----
$homeCandidates = @(
  $env:HOMEASSISTANT_HOME,         # optional env override
  $HomeRoot,                        # parameter
  "Z:\",                            # Windows mapped share
  "/mnt/homeassistant_config",      # code-server common mount
  "/config",                        # HA OS container path (if run inside)
  "$HOME/homeassistant",            # generic
  "$HOME/ha"                        # generic
)

$publicCandidates = @(
  $env:HOMEASSISTANT_PUBLIC,        # optional env override
  $PublicRoot,                      # parameter
  "C:\Git\homeassistant-public",    # Windows typical
  "$HOME/homeassistant-public",     # Linux typical
  "$HOME/git/homeassistant-public"  # Linux alt
)

$homeRootResolved   = Resolve-FirstExisting $homeCandidates
$publicRootResolved = Resolve-FirstExisting $publicCandidates

if (-not $homeRootResolved)  { throw "❌ Could not find private repo root. Use -HomeRoot or set HOMEASSISTANT_HOME." }
if (-not (Test-Path (Join-Path $homeRootResolved '.git'))) {
  throw "❌ '$homeRootResolved' is not a git repo (no .git)."
}

# Only resolve public later when/if user opts in; still capture now if present
if ($publicRootResolved -and -not (Test-Path (Join-Path $publicRootResolved '.git'))) {
  throw "❌ '$publicRootResolved' exists but is not a git repo (no .git)."
}

# ---- Folders to mirror ----
$foldersToSync = @("documentation","dashboards","packages")

# ---- Get commit message (popup on Windows, prompt otherwise) ----
function Get-CommitMessage {
  param([string]$DefaultMsg)
  if ($PSBoundParameters.ContainsKey('Message') -and -not [string]::IsNullOrWhiteSpace($Message)) {
    return $Message
  }
  $def = if ($DefaultMsg) { $DefaultMsg } else { "Update from $(Get-Date -Format 'yyyy-MM-dd HH:mm')" }
  if ($IsWindows) {
    try {
      Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
      return [Microsoft.VisualBasic.Interaction]::InputBox("Enter commit message for the homeassistant repo:", "Commit to homeassistant", $def)
    } catch {
      # Fallback if running PowerShell 7 without WinForms
      return Read-Host "Enter commit message for the homeassistant repo (default: '$def')" 
    }
  } else {
    $msg = Read-Host "Enter commit message for the homeassistant repo (default: '$def')"
    if ([string]::IsNullOrWhiteSpace($msg)) { return $def } else { return $msg }
  }
}

$commitMessage = Get-CommitMessage
if ([string]::IsNullOrWhiteSpace($commitMessage)) { Write-Host "❌ No commit message entered. Aborting."; exit 1 }

# ---- Helper: run git and fail if exit code != 0 ----
function Git-Run {
  param([string]$Cmd, [switch]$IgnoreError)
  & git $Cmd
  $code = $LASTEXITCODE
  if (-not $IgnoreError -and $code -ne 0) { throw "Git command failed: git $Cmd (exit $code)" }
}

# ---- PRIVATE REPO: stage → commit → push (current branch) ----
Set-Location $homeRootResolved
Write-Host "📂 Private repo: $homeRootResolved"
Write-Host "🧩 Staging all changes..."
Git-Run "add -A"

$staged = git diff --cached --name-status
if ([string]::IsNullOrWhiteSpace($staged)) {
  Write-Host "✅ No new changes to commit in private repo."
} else {
  Write-Host "📝 Committing..."
  Git-Run "commit -m `"$commitMessage`""
  $privBranch = (git rev-parse --abbrev-ref HEAD).Trim()
  Write-Host "📌 Branch (private): $privBranch"
  Write-Host "🚀 Pushing origin/$privBranch..."
  Git-Run "push origin $privBranch"
  Write-Host "✅ Pushed to private repo."
}

# ---- Ask to sync public ----
$syncPrompt = if ($IsWindows) { Read-Host "`nAlso sync selected folders to homeassistant-public? (y/n)" } else { Read-Host "`nAlso sync selected folders to homeassistant-public? (y/n)" }
if ($syncPrompt -notin @('y','Y')) { Write-Host "ℹ️ Skipping public sync."; exit 0 }

# Ensure public path (resolve again now in case user set an env/param just before)
if (-not $publicRootResolved) {
  # Try resolving again (maybe the user set an env var just now)
  $publicRootResolved = Resolve-FirstExisting $publicCandidates
}
if (-not $publicRootResolved) { throw "❌ Could not find public repo. Use -PublicRoot or set HOMEASSISTANT_PUBLIC." }
if (-not (Test-Path (Join-Path $publicRootResolved '.git'))) {
  throw "❌ '$publicRootResolved' is not a git repo (no .git)."
}

# ---- PUBLIC REPO: pull --ff-only; abort if dirty before copying ----
Set-Location $publicRootResolved
Write-Host "`n📂 Public repo: $publicRootResolved"
$pubBranch = (git rev-parse --abbrev-ref HEAD).Trim()
Write-Host "📌 Branch (public): $pubBranch"

Write-Host "🔄 git pull --ff-only origin $pubBranch"
Git-Run "pull --ff-only origin $pubBranch"

$preStatus = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($preStatus)) {
  throw @"
⚠️ Public repo has local changes BEFORE sync.

Likely you edited files directly in the public repo.
To avoid overwriting them, sync is aborted.

👉 Do this:
  1) Copy desired edits back into the private repo: $homeRootResolved
  2) Commit & push from the private repo
  3) Re-run this script
"@
}

# ---- Copy selected folders (non-destructive per-folder replace) ----
Write-Host "`n🔁 Syncing folders from $homeRootResolved → $publicRootResolved"
foreach ($folder in $foldersToSync) {
  $src = Join-Path $homeRootResolved $folder
  $dst = Join-Path $publicRootResolved $folder
  if (-not (Test-Path $src)) {
    Write-Warning "Skipping '$folder' (missing at source: $src)"
    continue
  }
  Write-Host "🧹 Clean target: $dst"
  if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
  Write-Host "📁 Copy $src → $dst"
  Copy-Item $src -Destination $dst -Recurse
}

# Ensure README exists
$readmePath = Join-Path $publicRootResolved "README.md"
if (-not (Test-Path $readmePath)) {
@"
# HomeAssistant Public Export

This repository contains a public mirror of selected folders from my private Home Assistant configuration:

- \`documentation\`
- \`dashboards\`
- \`packages\`

The private configuration (including secrets) remains in a separate private repository.
"@ | Set-Content $readmePath -Encoding UTF8
}

# ---- PUBLIC REPO: stage → commit (same message) → push ----
Write-Host "`n🧩 Staging public changes..."
Git-Run "add -A"

$pubStaged = git diff --cached --name-status
if ([string]::IsNullOrWhiteSpace($pubStaged)) {
  Write-Host "✅ No new changes to commit in public repo."
} else {
  Write-Host "📝 Committing to public..."
  Git-Run "commit -m `"$commitMessage`""
  Write-Host "🚀 Pushing origin/$pubBranch..."
  Git-Run "push origin $pubBranch"
  Write-Host "✅ Pushed to public repo."
}

Write-Host "`n🎉 Done."
