<#
Cross-platform (Windows + Linux/code-server)
Syncs your private Home Assistant repo → commits & pushes,
then optionally mirrors documentation, dashboards, and packages
to your public repo with the same commit message.

Supports:
- Path auto-detection (override via -HomeRoot/-PublicRoot or env vars)
- Safety: public pull --ff-only, abort if dirty before copying
- Same commit message in both repos
#>

[CmdletBinding()]
param(
  [string]$HomeRoot,
  [string]$PublicRoot,
  [string]$Message,
  [switch]$UseDefaultMessage,
  [switch]$SyncPublic,
  [switch]$SkipPublic,
  [ValidateSet("Prompt","UsePrivate","KeepPublic","Abort")]
  [string]$ConflictPolicy = "Prompt"
)

$ForbiddenFileNames = @(
  "secrets.yaml",
  "secret.yaml",
  "scripts.yaml",
  ".storage",
  "auth",
  "auth_provider"
)

$ForbiddenContentPatterns = @(
  "verisure",
  "token",
  "password",
  "passwd",
  "secret",
  "pin",
  "bearer ",
  "authorization:"
)
$script:ForbiddenContentRegexes = @()
$script:ForbiddenPatternLookup = @{}
foreach ($pattern in $ForbiddenContentPatterns) {
  $escaped = [regex]::Escape($pattern)
  $regex = "(?i)$escaped"
  $script:ForbiddenContentRegexes += $regex
  $script:ForbiddenPatternLookup[$regex] = $pattern
}

if ($HomeRoot -and -not (Test-Path $HomeRoot)) {
  throw "❌ Provided HomeRoot '$HomeRoot' does not exist."
}
if ($PublicRoot -and -not (Test-Path $PublicRoot)) {
  throw "❌ Provided PublicRoot '$PublicRoot' does not exist."
}

# ---------- Utilities ----------
function Resolve-FirstExisting {
  param([string[]]$Candidates)
  foreach ($c in $Candidates) { if ($c -and (Test-Path $c)) { return (Resolve-Path $c).Path } }
  return $null
}

function Normalize-RelativePath {
  param(
    [string]$BasePath,
    [string]$FullPath
  )
  $normalized = [IO.Path]::GetRelativePath($BasePath, $FullPath)
  return ($normalized -replace "\\","/")
}

function In-SyncScope {
  param(
    [string]$RelativePath,
    [string[]]$Folders,
    [string[]]$Files
  )
  $path = $RelativePath -replace "\\","/"
  foreach ($folder in $Folders) {
    $folderNorm = $folder -replace "\\","/"
    if ($path -eq $folderNorm -or $path.StartsWith("$folderNorm/")) { return $true }
  }
  foreach ($file in $Files) {
    if ($path -eq ($file -replace "\\","/")) { return $true }
  }
  return $false
}

function Resolve-ConflictDecision {
  param(
    [string]$Path,
    [string]$Status,
    [string]$Policy
  )
  switch ($Policy.ToLowerInvariant()) {
    "useprivate" { return "private" }
    "keeppublic" { return "keep" }
    "abort"      { return "abort" }
    default {
      while ($true) {
        $choice = Read-Host "Local change '$Path' (status $Status). Choose: [P]rivate / [K]eep public / [A]bort"
        if ([string]::IsNullOrWhiteSpace($choice)) { return "private" }
        $choiceValue = $choice.Trim().ToLowerInvariant()
        switch ($choiceValue) {
          {$_ -eq "" -or $_ -eq "p"} { return "private" }
          {$_ -eq "k"} { return "keep" }
          {$_ -eq "a"} { return "abort" }
          default { Write-Host "Please enter P, K, or A." }
        }
      }
    }
  }
}

function Confirm-SecretOverride {
  param(
    [string]$PhaseLabel,
    [string]$RelativePath,
    [string]$MatchDetail
  )
  $baseMessage = "[sync-ha-public] BLOCKED ($PhaseLabel): Potential secret in '$RelativePath' $MatchDetail."
  Write-Error $baseMessage
  while ($true) {
    $response = Read-Host "Continue anyway? (y/N)"
    if ([string]::IsNullOrWhiteSpace($response)) {
      throw "$baseMessage Aborting sync."
    }
    $choice = $response.Trim().ToLowerInvariant()
    switch ($choice) {
      "y" { Write-Warning "[sync-ha-public] Continuing despite detection in '$RelativePath'."; return }
      "yes" { Write-Warning "[sync-ha-public] Continuing despite detection in '$RelativePath'."; return }
      "n" { throw "$baseMessage Aborting sync." }
      "no" { throw "$baseMessage Aborting sync." }
      default { Write-Host "Please answer y or n." }
    }
  }
}

function Get-SyncFileCandidates {
  param(
    [string]$RootPath,
    [string[]]$Folders,
    [string[]]$Files,
    [string[]]$AdditionalRelativeFiles = @()
  )
  $results = New-Object System.Collections.Generic.List[object]
  if (-not $RootPath) { return $results }
  $seenPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $addCandidate = {
    param([string]$CandidatePath)
    if (-not (Test-Path -LiteralPath $CandidatePath)) { return }
    $resolved = (Resolve-Path -LiteralPath $CandidatePath).Path
    if (-not $seenPaths.Add($resolved)) { return }
    $results.Add([pscustomobject]@{
      FullPath     = $resolved
      RelativePath = Normalize-RelativePath -BasePath $RootPath -FullPath $resolved
    })
  }
  foreach ($folder in $Folders) {
    if (-not $folder) { continue }
    $folderPath = Join-Path $RootPath $folder
    if (-not (Test-Path -LiteralPath $folderPath)) { continue }
    $filesInFolder = Get-ChildItem -LiteralPath $folderPath -File -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($entry in $filesInFolder) {
      & $addCandidate $entry.FullName
    }
  }
  foreach ($rel in ($Files + $AdditionalRelativeFiles | Where-Object { $_ })) {
    $filePath = Join-Path $RootPath $rel
    & $addCandidate $filePath
  }
  return $results
}

function Invoke-SecretScan {
  param(
    [string]$RootPath,
    [string]$PhaseLabel,
    [string[]]$Folders,
    [string[]]$Files,
    [string[]]$ForbiddenNames,
    [string[]]$ForbiddenContentRegexes,
    [string[]]$AdditionalRelativeFiles = @()
  )
  $candidates = Get-SyncFileCandidates -RootPath $RootPath -Folders $Folders -Files $Files -AdditionalRelativeFiles $AdditionalRelativeFiles
  if ($candidates.Count -eq 0) {
    Write-Host "ℹ️ No files to scan for $PhaseLabel."
    return
  }
  Write-Host "🔐 Scanning $PhaseLabel content for forbidden names or patterns..."
  foreach ($candidate in $candidates) {
    $relativePath = $candidate.RelativePath
    $segments = $relativePath -split "/"
    $hasForbiddenName = $false
    foreach ($segment in $segments) {
      if ([string]::IsNullOrWhiteSpace($segment)) { continue }
      if ($ForbiddenNames -contains $segment) {
        Confirm-SecretOverride -PhaseLabel $PhaseLabel -RelativePath $relativePath -MatchDetail "containing forbidden name '$segment'"
        $hasForbiddenName = $true
        break
      }
    }
    if ($hasForbiddenName) { continue }
    try {
      $matchInfo = $null
      if ($ForbiddenContentRegexes.Count -gt 0) {
        $matchInfo = Select-String -LiteralPath $candidate.FullPath -Pattern $ForbiddenContentRegexes -ErrorAction Stop | Select-Object -First 1
      }
    } catch {
      $err = "[sync-ha-public] BLOCKED ($PhaseLabel): Unable to scan '$relativePath' for sensitive content. $($_.Exception.Message)"
      Write-Error $err
      throw $err
    }
    if ($matchInfo) {
      $patternKey = $matchInfo.Pattern
      $patternDisplay = if ($script:ForbiddenPatternLookup.ContainsKey($patternKey)) { $script:ForbiddenPatternLookup[$patternKey] } else { $patternKey }
      Confirm-SecretOverride -PhaseLabel $PhaseLabel -RelativePath $relativePath -MatchDetail "matching pattern '$patternDisplay'"
      continue
    }
  }
}

$script:GitExecutable = $null
function Git {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$CommandArgs
  )
  if (-not $script:GitExecutable) {
    $gitCmd = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
      throw "git not found on PATH"
    }
    $script:GitExecutable = $gitCmd.Source
  }
  $gitArgs = @('--no-pager') + @($CommandArgs)
  $output = & $script:GitExecutable @gitArgs
  $code = $LASTEXITCODE
  if ($code -ne 0) { throw "Git command failed: git $($gitArgs -join ' ') (exit $code)" }
  return $output
}

# ---------- Path candidates ----------
$scriptDir = Split-Path -Parent $PSCommandPath
$scriptRoot = Split-Path -Parent $scriptDir

$homeCandidates = @(
  $HomeRoot, $env:HOMEASSISTANT_HOME,
  $scriptRoot,
  "Z:\", "/mnt/homeassistant_config", "/config",
  "$HOME/homeassistant", "$HOME/ha"
)
$publicCandidates = @(
  $PublicRoot, $env:HOMEASSISTANT_PUBLIC,
  (Join-Path $scriptRoot "homeassistant-public"),
  "C:\Git\homeassistant-public", "$HOME/homeassistant-public", "$HOME/git/homeassistant-public"
)

$homeRootResolved   = Resolve-FirstExisting $homeCandidates
$publicRootResolved = Resolve-FirstExisting $publicCandidates

if ($SyncPublic -and $SkipPublic) {
  throw "❌ Cannot supply both -SyncPublic and -SkipPublic."
}

if (-not $homeRootResolved)  { throw "❌ Could not find private repo root. Use -HomeRoot or set HOMEASSISTANT_HOME." }
if (-not (Test-Path (Join-Path $homeRootResolved '.git'))) {
  throw "❌ '$homeRootResolved' is not a git repo (no .git)."
}
if ($publicRootResolved -and -not (Test-Path (Join-Path $publicRootResolved '.git'))) {
  throw "❌ '$publicRootResolved' exists but is not a git repo (no .git)."
}

$foldersToSync = @("documentation","dashboards","packages","scripts")
$filesToSync   = @("automations.yaml","scripts.yaml")

# ---------- Commit message ----------
function Get-CommitMessage {
  param(
    [string]$ProvidedMessage,
    [switch]$ForceDefault
  )
  if (-not [string]::IsNullOrWhiteSpace($ProvidedMessage)) { return $ProvidedMessage }
  $def = "Update from $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
  if ($ForceDefault) { return $def }
  if ($IsWindows) {
    try {
      Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
      $input = [Microsoft.VisualBasic.Interaction]::InputBox("Enter commit message for the homeassistant repo:", "Commit", $def)
      if ([string]::IsNullOrWhiteSpace($input)) { return $def } else { return $input }
    } catch {
      $fallback = Read-Host "Enter commit message (default: '$def')"
      if ([string]::IsNullOrWhiteSpace($fallback)) { return $def } else { return $fallback }
    }
  } else {
    $msg = Read-Host "Enter commit message (default: '$def')"
    if ([string]::IsNullOrWhiteSpace($msg)) { return $def } else { return $msg }
  }
}
$commitMessage = Get-CommitMessage -ProvidedMessage $Message -ForceDefault:$UseDefaultMessage
if ([string]::IsNullOrWhiteSpace($commitMessage)) { throw "❌ No commit message entered. Aborting." }

# ---------- PRIVATE REPO ----------
Push-Location $homeRootResolved
try {
  $privBranch = (Git rev-parse --abbrev-ref HEAD).Trim()
  Write-Host "📂 Private repo: $homeRootResolved"
  Write-Host "📌 Branch (private): $privBranch"
  Write-Host "🧩 Staging all changes..."
  Git add -A

  $staged = Git diff --cached --name-status
  if ([string]::IsNullOrWhiteSpace($staged)) {
    Write-Host "✅ No new changes to commit in private repo."
  } else {
    Write-Host "📝 Committing..."
    Git commit -m "$commitMessage"
    Write-Host "🚀 Pushing origin/$privBranch..."
    Git push origin $privBranch
    Write-Host "✅ Pushed to private repo."
  }
} finally {
  Pop-Location
}

# ---------- ASK SYNC PUBLIC ----------
$syncDecision = $false
if ($SyncPublic) {
  $syncDecision = $true
} elseif ($SkipPublic) {
  $syncDecision = $false
} else {
  $syncPrompt = Read-Host "`nAlso sync selected folders to homeassistant-public? (y/n)"
  $syncDecision = $syncPrompt -in @('y','Y')
}
if (-not $syncDecision) { Write-Host "ℹ️ Skipping public sync."; return }

Invoke-SecretScan -RootPath $homeRootResolved `
  -PhaseLabel "private pre-flight" `
  -Folders $foldersToSync `
  -Files $filesToSync `
  -ForbiddenNames $ForbiddenFileNames `
  -ForbiddenContentRegexes $script:ForbiddenContentRegexes

# ---------- PUBLIC REPO (safety first) ----------
if (-not $publicRootResolved) {
  $publicRootResolved = Resolve-FirstExisting $publicCandidates
}
if (-not $publicRootResolved) { throw "❌ Could not find public repo. Use -PublicRoot or set HOMEASSISTANT_PUBLIC." }
if (-not (Test-Path (Join-Path $publicRootResolved '.git'))) {
  throw "❌ '$publicRootResolved' is not a git repo."
}

Push-Location $publicRootResolved
try {
  $pubBranch = (Git rev-parse --abbrev-ref HEAD).Trim()
  Write-Host "`n📂 Public repo: $publicRootResolved"
  Write-Host "📌 Branch (public): $pubBranch"

  Write-Host "🔄 git pull --ff-only origin $pubBranch"
  try { Git pull --ff-only origin $pubBranch } catch {
    throw "⚠️ Pull failed or diverged. Resolve manually before running again."
  }

  $preStatus = Git status --porcelain
  $preserveFiles = @()
  $preserveDeletions = @()
  if (-not [string]::IsNullOrWhiteSpace($preStatus)) {
    $statusLines = $preStatus -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $unrelatedChanges = @()
    foreach ($line in $statusLines) {
      $match = [regex]::Match($line, '^(..)\s+(.*)$')
      if (-not $match.Success) { continue }
      $rawStatus = $match.Groups[1].Value.Trim()
      $rawPath = $match.Groups[2].Value.Trim()
      $renameMatch = [regex]::Match($rawPath, '->\s*(.+)$')
      if ($renameMatch.Success) {
        $rawPath = $renameMatch.Groups[1].Value.Trim()
      }
      $scopeMatch = In-SyncScope -RelativePath $rawPath -Folders $foldersToSync -Files $filesToSync
      if (-not $scopeMatch) {
        $unrelatedChanges += $rawPath
        continue
      }
      $decision = Resolve-ConflictDecision -Path $rawPath -Status $rawStatus -Policy $ConflictPolicy
      if ($decision -eq "abort") {
        throw "Aborted by user."
      }
      if ($decision -eq "keep") {
        if ($rawStatus -like "*D*") {
          $preserveDeletions += $rawPath
        } else {
          $preserveFiles += $rawPath
        }
      }
    }
    if ($unrelatedChanges.Count -gt 0) {
      Write-Host "ℹ️ Public repo has additional local changes that are outside the sync scope:"
      $unrelatedChanges | Sort-Object -Unique | ForEach-Object { Write-Host "   - $_" }
    }
  }

  # ---------- SYNC FOLDERS ----------
  Write-Host "`n🔁 Syncing folders from $homeRootResolved → $publicRootResolved"
  $preserveRoot = $null
  if ($preserveFiles.Count -gt 0) {
    $preserveRoot = Join-Path $publicRootResolved ".sync-preserve"
    if (Test-Path $preserveRoot) { Remove-Item $preserveRoot -Recurse -Force }
    foreach ($rel in $preserveFiles) {
      $sourceKeep = Join-Path $publicRootResolved $rel
      if (-not (Test-Path $sourceKeep)) { continue }
      $destKeep = Join-Path $preserveRoot $rel
      $destDir = Split-Path $destKeep -Parent
      if ($destDir) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
      Copy-Item -LiteralPath $sourceKeep -Destination $destKeep -Force
    }
  }

  foreach ($folder in $foldersToSync) {
    $src = Join-Path $homeRootResolved $folder
    $dst = Join-Path $publicRootResolved $folder
    if (-not (Test-Path $src)) { Write-Warning "Skipping '$folder' (missing: $src)"; continue }
    Write-Host "🧹 Clean: $dst"
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force -ErrorAction Stop }
    Write-Host "📁 Copy $src → $dst"
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force -Container -ErrorAction Stop
  }

  if ($preserveRoot) {
    foreach ($rel in $preserveFiles) {
      $savedPath = Join-Path $preserveRoot $rel
      if (-not (Test-Path $savedPath)) { continue }
      $targetPath = Join-Path $publicRootResolved $rel
      $targetDir = Split-Path $targetPath -Parent
      if ($targetDir) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
      Copy-Item -LiteralPath $savedPath -Destination $targetPath -Force
    }
    Remove-Item $preserveRoot -Recurse -Force
  }

  foreach ($rel in $preserveDeletions | Select-Object -Unique) {
    $targetDel = Join-Path $publicRootResolved $rel
    if (Test-Path $targetDel) {
      Remove-Item $targetDel -Recurse -Force
    }
  }
  foreach ($file in $filesToSync) {
    $srcFile = Join-Path $homeRootResolved $file
    $dstFile = Join-Path $publicRootResolved $file
    if (-not (Test-Path $srcFile)) { Write-Warning "Skipping file '$file' (missing: $srcFile)"; continue }
    Write-Host "📄 Copy file $srcFile → $dstFile"
    Copy-Item -LiteralPath $srcFile -Destination $dstFile -Force -ErrorAction Stop
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
- \`scripts\`
- \`automations.yaml\`
- \`scripts.yaml\`

The private configuration (including secrets) remains in a separate private repository.
"@ | Set-Content $readmePath -Encoding UTF8
  }

  Invoke-SecretScan -RootPath $publicRootResolved `
    -PhaseLabel "public post-sync" `
    -Folders $foldersToSync `
    -Files $filesToSync `
    -ForbiddenNames $ForbiddenFileNames `
    -ForbiddenContentRegexes $script:ForbiddenContentRegexes `
    -AdditionalRelativeFiles @("README.md")

  # ---------- COMMIT PUBLIC ----------
  Write-Host "`n🧩 Staging public changes..."
  Git add -A

  $pubStaged = Git diff --cached --name-status
  if ([string]::IsNullOrWhiteSpace($pubStaged)) {
    Write-Host "✅ No new changes to commit in public repo."
  } else {
    Write-Host "📝 Committing to public..."
    Git commit -m "$commitMessage"
    Write-Host "🚀 Pushing origin/$pubBranch..."
    Git push origin $pubBranch
    Write-Host "✅ Pushed to public repo."
  }
} finally {
  Pop-Location
}

Write-Host "`n🎉 Done."
