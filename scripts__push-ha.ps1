param(
    [string]$RepoPath = "/mnt/homeassistant_config",  # Private HA config repo root
    [string]$Message,
    [switch]$DryRun
)

function Write-Info($Text) { Write-Host "[push-ha] $Text" }

if (-not (Test-Path $RepoPath)) {
    Write-Error "[push-ha] RepoPath '$RepoPath' does not exist."
    exit 1
}

Set-Location $RepoPath

# Show current branch + status
Write-Info ("Current branch: " + (git rev-parse --abbrev-ref HEAD))
$changes = git status --porcelain

if (-not $changes) {
    Write-Info "No changes to commit. Exiting."
    exit 0
}

Write-Info "Changes to be committed:"
git status

if (-not $Message) {
    $default = "Update from $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    $Message = Read-Host "Enter commit message (default: '$default')"
    if ([string]::IsNullOrWhiteSpace($Message)) {
        $Message = $default
    }
}

Write-Info "Using commit message: '$Message'"

if ($DryRun) {
    Write-Info "DRY RUN: Would run:"
    Write-Host "  git add -A"
    Write-Host "  git commit -m `"$Message`""
    Write-Host "  git push"
    exit 0
}

try {
    git add -A
    git commit -m "$Message"
    git push
    Write-Info "Private repo push completed."
}
catch {
    Write-Error "[push-ha] Git operation failed: $($_.Exception.Message)"
    exit 1
}
