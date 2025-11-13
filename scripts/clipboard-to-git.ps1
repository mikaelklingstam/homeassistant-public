<#
  clipboard-to-git.ps1 - Saves ChatGPT clipboard blocks into a git repository.

  Clipboard format:
    ---save---
    path: relative/path/to/file.ext
    mode: overwrite|append
    ---
    <file content>

  The script polls the clipboard, writes the content to disk, stages the file,
  commits with a timestamped message, and pushes to the detected branch.
  Activity is logged to Logs\clipboard-to-git.log.
#>

param(
  [string]$RepoRoot = 'Z:\',
  [int]$PollMs = 2000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log {
  param([Parameter(Mandatory)][string]$Message)

  $logDir = Join-Path $RepoRoot 'Logs'
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
  }

  $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "$stamp  $Message" | Out-File -FilePath (Join-Path $logDir 'clipboard-to-git.log') -Encoding utf8 -Append
}

function Test-GitEnvironment {
  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    throw 'Git is not available in PATH. Install Git for Windows and restart.'
  }

  if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
    throw "No .git directory found in $RepoRoot. Run 'git init' in the repo root."
  }
}

function Invoke-GitCommand {
  param([Parameter(Mandatory)][string[]]$Arguments)

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.ArgumentList.AddRange($Arguments)
  $psi.WorkingDirectory = $RepoRoot
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false

  $process = [System.Diagnostics.Process]::Start($psi)
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  if ($stdout.Trim()) { Write-Log "[git OUT] $stdout" }
  if ($stderr.Trim()) { Write-Log "[git ERR] $stderr" }

  if ($process.ExitCode -ne 0) {
    throw "git exited with code $($process.ExitCode) for args: $($Arguments -join ' ')"
  }

  return $stdout
}

function Invoke-GitPush {
  param([Parameter(Mandatory)][string]$TargetRef)

  $hasUpstream = $true
  try {
    Invoke-GitCommand @('rev-parse','--abbrev-ref','--symbolic-full-name','@{u}') | Out-Null
  } catch {
    $hasUpstream = $false
  }

  if (-not $hasUpstream) {
    Write-Log "[info] No upstream set. Pushing with -u to origin/$TargetRef."
    Invoke-GitCommand @('push','-u','origin',"HEAD:$TargetRef") | Out-Null
  } else {
    Invoke-GitCommand @('push','origin',"HEAD:$TargetRef") | Out-Null
  }
}

function Set-RepoFileContent {
  param(
    [Parameter(Mandatory)][string]$PathRel,
    [Parameter(Mandatory)][string]$Mode,
    [Parameter(Mandatory)][string]$Content
  )

  $fullPath = Join-Path $RepoRoot $PathRel
  $targetDir = Split-Path $fullPath -Parent
  if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
  }

  switch ($Mode.ToLowerInvariant()) {
    'append' { Add-Content -Path $fullPath -Value $Content -Encoding UTF8 }
    default  { Set-Content -Path $fullPath -Value $Content -Encoding UTF8 }
  }

  Invoke-GitCommand @('add','--',"$PathRel") | Out-Null

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = 'git'
  $psi.ArgumentList.AddRange(@('diff','--cached','--quiet'))
  $psi.WorkingDirectory = $RepoRoot
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $process = [System.Diagnostics.Process]::Start($psi)
  $process.WaitForExit()

  return ($process.ExitCode -ne 0)
}

function Invoke-CommitPush {
  param([Parameter(Mandatory)][string]$TargetRef)

  $message = "Auto-save from ChatGPT -> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  Invoke-GitCommand @('commit','-m',"$message") | Out-Null
  Invoke-GitPush -TargetRef $TargetRef
  Write-Log "[done] Commit and push completed for origin/$TargetRef."
}

function Get-TargetRef {
  try {
    $upstream = (git -C $RepoRoot rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
    if ($LASTEXITCODE -eq 0 -and $upstream) {
      if ($upstream -match '^[^/]+/(.+)$') {
        return $Matches[1].Trim()
      }
    }
  } catch {
  }

  $hasMain   = (git -C $RepoRoot ls-remote --heads origin main) 2>$null
  $hasMaster = (git -C $RepoRoot ls-remote --heads origin master) 2>$null
  if ($hasMain -and $hasMain.Trim())   { return 'main' }
  if ($hasMaster -and $hasMaster.Trim()) { return 'master' }
  return 'main'
}

$pattern = '---save---\s*\n\s*path:\s*(?<path>.+?)\s*\n\s*mode:\s*(?<mode>overwrite|append)\s*\n---\s*\n(?<body>.*?)(?=\n```|\Z)'

Test-GitEnvironment
Add-Type -AssemblyName PresentationCore
$lastHash = ''
$hasher = [System.Security.Cryptography.SHA256]::Create()
Write-Log "[start] Clipboard listener at $RepoRoot (poll ${PollMs}ms)."

$targetRef = Get-TargetRef
Write-Log "[info] Target push branch: $targetRef"

while ($true) {
  try {
    $text = Get-Clipboard -TextFormatType Text
    if ($null -ne $text -and $text.Trim()) {
      $hash = [BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))
      if ($hash -ne $lastHash) {
        $lastHash = $hash

        $normalized = $text -replace "`r`n", "`n" -replace "`r", "`n"
        $trimmed = $normalized.Trim()
        if ($trimmed.StartsWith('```')) {
          $trimmed = $trimmed.Trim('`')
        }

        $matches = [Regex]::Matches(
          $trimmed,
          $pattern,
          [System.Text.RegularExpressions.RegexOptions]::Singleline -bor
          [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($matches.Count -gt 0) {
          $match = $matches[0]
          $relativePath = $match.Groups['path'].Value.Trim()
          $mode = $match.Groups['mode'].Value.Trim()
          $body = $match.Groups['body'].Value

          if ($relativePath -match '^\s*(\.\.|[\\/])') {
            Write-Log "[warn] Ignored unsafe path: $relativePath"
          } else {
            Write-Log "[hit] Saving $relativePath ($mode)."
            $changed = Set-RepoFileContent -PathRel $relativePath -Mode $mode -Content $body
            if ($changed) {
              Invoke-CommitPush -TargetRef $targetRef
            } else {
              Write-Log "[skip] No staged changes for $relativePath."
            }
          }
        } else {
          Write-Log "[miss] Clipboard changed but no ---save--- block found."
        }
      }
    }
  } catch {
    Write-Log "[error] $($_.Exception.Message)"
  }

  Start-Sleep -Milliseconds $PollMs
}
