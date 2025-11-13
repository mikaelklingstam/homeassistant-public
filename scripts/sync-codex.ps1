<#
  sync-codex.ps1 - Safe Git sync with interactive conflict resolver

  Steps:
    1. Stash local changes (if any)
    2. Fetch and ensure an upstream is configured
    3. Pull with --rebase
    4. Resolve conflicts interactively (auto options available)
    5. Re-apply stash, commit, and push

  Usage:
    .\sync-codex.ps1
    .\sync-codex.ps1 -AutoRemote   # always prefer remote during conflicts
    .\sync-codex.ps1 -AutoLocal    # always prefer local during conflicts
#>

[CmdletBinding()]
param(
  [switch]$AutoRemote,
  [switch]$AutoLocal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
  param([Parameter(Mandatory)][string]$Message)
  $repoRoot = Get-Location
  $logDir   = Join-Path -Path $repoRoot -ChildPath 'Logs'
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
  }
  $logPath  = Join-Path -Path $logDir -ChildPath 'sync.log'
  $stamp    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "$stamp  $Message" | Out-File -FilePath $logPath -Append -Encoding utf8
  Write-Host $Message
}

function Assert-GitRepo {
  if (-not (Test-Path '.git')) {
    $here = Get-Location
    throw "No .git directory found in $here. Run the script from the repo root (e.g. Z:\)."
  }
}

function Show-Diff {
  param([Parameter(Mandatory)][string]$Path)
  Write-Host "`n===== DIFF: $Path =====`n"
  try {
    & git diff -- "$Path" | more
  } catch {
    Write-Host "Could not show diff for $Path"
  }
}

function Resolve-File {
  param([Parameter(Mandatory)][string]$File)
  while ($true) {
    Write-Host ""
    Write-Host "Conflict in: $File"
    Write-Host "[R] Keep REMOTE (theirs)"
    Write-Host "[L] Keep LOCAL (ours)"
    Write-Host "[V] View diff"
    Write-Host "[E] Open in VS Code"
    Write-Host "[S] Skip / abort"
    $choice = Read-Host "Choose (R/L/V/E/S)"
    switch ($choice.ToUpper()) {
      'R' {
        & git checkout --theirs -- "$File"
        & git add "$File"
        Write-Host "[resolved] Kept REMOTE for $File"
        return
      }
      'L' {
        & git checkout --ours -- "$File"
        & git add "$File"
        Write-Host "[resolved] Kept LOCAL for $File"
        return
      }
      'V' { Show-Diff -Path $File }
      'E' { code "$File" }
      'S' { throw "Aborted by user." }
      default { Write-Host "Invalid option." }
    }
  }
}

function Resolve-All-Conflicts {
  $conflictedRaw = (& git diff --name-only --diff-filter=U) 2>$null
  $conflicted = @()
  if ($null -ne $conflictedRaw) {
    $conflicted = $conflictedRaw -split "`n" | Where-Object { $_ -and $_.Trim() -ne '' }
  }

  if ($conflicted.Count -eq 0) { return $false }

  Write-Host ""
  Write-Host "[conflict] Conflicts detected in:"
  $conflicted | ForEach-Object { Write-Host " - $_" }

  if ($AutoRemote) {
    foreach ($f in $conflicted) { & git checkout --theirs -- "$f"; & git add "$f" }
    Write-Log "AutoRemote: kept REMOTE in ${($conflicted.Count)} file(s)."
  }
  elseif ($AutoLocal) {
    foreach ($f in $conflicted) { & git checkout --ours -- "$f"; & git add "$f" }
    Write-Log "AutoLocal: kept LOCAL in ${($conflicted.Count)} file(s)."
  }
  else {
    foreach ($f in $conflicted) { Resolve-File -File $f }
  }
  return $true
}

function Complete-RebaseOrMerge {
  $rebaseApply = Test-Path '.git/rebase-apply'
  $rebaseMerge = Test-Path '.git/rebase-merge'
  if ($rebaseApply -or $rebaseMerge) {
    try {
      & git rebase --continue | Out-Null
    }
    catch {
      throw "Failed to continue rebase. Run 'git rebase --abort' to roll back."
    }
    return
  }

  try {
    & git diff --cached --quiet
    $hasStaged = $LASTEXITCODE -ne 0
    if ($hasStaged) {
      & git commit -m 'Resolve merge conflicts' | Out-Null
    }
  } catch {
  }
}

try {
  Assert-GitRepo
  $startBranch = (& git rev-parse --abbrev-ref HEAD).Trim()
  Write-Log "[start] Syncing branch '${startBranch}' in $(Get-Location)."

  # 1) Stash local changes
  $status = (& git status --porcelain)
  $needStash = ($null -ne $status -and $status.Trim() -ne '')
  $stashName = "pre-sync-$(Get-Date -Format 'yyyyMMddHHmmss')"
  if ($needStash) {
    & git stash push -u -m $stashName | Out-Null
    Write-Log "[stash] Stored local changes: ${stashName}"
  } else {
    Write-Log "[stash] No local changes to stash."
  }

  # 2) Fetch + upstream detection
  & git fetch origin --prune
  $upstream = (& git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
  if ($LASTEXITCODE -ne 0 -or $null -eq $upstream -or $upstream.Trim() -eq '') {
    $hasMain   = (& git ls-remote --heads origin main)
    $hasMaster = (& git ls-remote --heads origin master)
    if ($null -ne $hasMain -and $hasMain.Trim() -ne '') {
      & git branch --set-upstream-to origin/main | Out-Null
      $upstream = 'origin/main'
    } elseif ($null -ne $hasMaster -and $hasMaster.Trim() -ne '') {
      & git branch --set-upstream-to origin/master | Out-Null
      $upstream = 'origin/master'
    } else {
      throw "No upstream configured. Run: git branch --set-upstream-to origin/main"
    }
  }
  $upstream = $upstream.Trim()
  Write-Log "[fetch] Upstream set to ${upstream}"

  # Show quick overview of upstream changes
  Write-Host "`n[info] New commits from ${upstream}:"
  try { & git log --oneline "HEAD..${upstream}" } catch { }
  Write-Host "`n[info] Files differing between local HEAD and ${upstream}:"
  try { & git diff --name-status "${upstream}...HEAD" } catch { }

  # 3) Pull --rebase
  $pullOk = $true
  try {
    & git -c rebase.autoStash=true pull --rebase
    Write-Log "[pull] Pull --rebase completed without conflicts."
  } catch {
    Write-Log "[conflict] Pull --rebase hit conflicts. Starting conflict resolution..."
    $pullOk = $false
  }

  if (-not $pullOk) {
    do {
      $resolved = Resolve-All-Conflicts
      if ($resolved) { Complete-RebaseOrMerge }
      $conflictedNow = (& git diff --name-only --diff-filter=U)
      $stillConflicted = ($null -ne $conflictedNow -and $conflictedNow.Trim() -ne '')
    } while ($stillConflicted)
    Write-Log "[resolved] Conflicts resolved."
  }

  # 4) Reapply stash if it exists
  $stashes = (& git stash list)
  $hadStash = ($null -ne $stashes -and $stashes -match [regex]::Escape($stashName))
  if ($hadStash) {
    Write-Log "[stash] Re-applying stash ${stashName}..."
    try {
      & git stash pop
      Write-Log "[stash] Stash pop completed."
    } catch {
      Write-Log "[conflict] Conflicts during stash pop. Resolving interactively."
      do {
        $resolved = Resolve-All-Conflicts
        if ($resolved) { Complete-RebaseOrMerge }
        $conflictedNow = (& git diff --name-only --diff-filter=U)
        $stillConflicted = ($null -ne $conflictedNow -and $conflictedNow.Trim() -ne '')
      } while ($stillConflicted)
      Write-Log "[resolved] Conflicts after stash pop resolved."
    }
  }

  # 5) Commit + push
  & git diff --quiet
  $hasWorkingChanges = $LASTEXITCODE -ne 0
  & git diff --cached --quiet
  $hasStagedChanges = $LASTEXITCODE -ne 0

  if ($hasWorkingChanges -or $hasStagedChanges) {
    & git add -A
    $msg = "Sync Codex & ChatGPT changes on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    & git commit -m "$msg"
    Write-Log "[commit] Commit created: $msg"
  } else {
    Write-Log "[commit] No new changes to commit."
  }

  & git push
  Write-Log "[done] Push complete. Sync finished."
  Write-Host "`n[done] Finished. See Logs\sync.log for details."

} catch {
  Write-Log ("[error] " + $_.Exception.Message)
  Write-Host "`nIf you need to abort an in-progress rebase/merge:"
  Write-Host "    git rebase --abort"
  Write-Host "    git merge --abort"
  exit 1
}
