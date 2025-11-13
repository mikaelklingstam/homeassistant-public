# sync-readme.ps1 – Sync Rulebook and Action Plan to GitHub
# Author: Mikael Klingstam (HomeAssistant 1.1 project)
# Purpose: Ensure all main documentation stays aligned between local HA config and GitHub.

$repo        = "Z:\"                                        # Repository root
$rulebook    = "Z:\documentation\rulebook_homeassistant_1_1.md"
$actionplan  = "Z:\documentation\action_plan.md"
$target      = "README.md"

Write-Host "🔍 Checking for documentation updates..." -ForegroundColor Cyan

# --- Rulebook diff check ---
if (Test-Path "$repo\$target" -and (Test-Path $rulebook)) {
    $diffRulebook = Compare-Object -ReferenceObject (Get-Content "$repo\$target") `
                                   -DifferenceObject (Get-Content $rulebook)
    if ($diffRulebook) {
        Write-Host "`n📝 Differences found between Rulebook and README:`n" -ForegroundColor Yellow
        $diffRulebook | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }
        $confirmRule = Read-Host "`nApply Rulebook changes to README and commit? (y/n)"
        if ($confirmRule -ne "y") { Write-Host "❌ Rulebook sync cancelled."; exit }
        Copy-Item $rulebook -Destination "$repo\$target" -Force
    } else {
        Write-Host "✅ Rulebook and README already identical." -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ Rulebook or README not found; skipping diff check." -ForegroundColor Yellow
}

# --- Action Plan diff check ---
if (Test-Path $actionplan) {
    $diffAction = Compare-Object -ReferenceObject (Get-Content $actionplan) `
                                 -DifferenceObject (Get-Content $actionplan)
    # (Compare to itself for syntax; replace with GitHub remote diff if needed)
    Write-Host "`n📘 Checking Action Plan changes..."
    $localGitStatus = git status --porcelain documentation/action_plan.md
    if ($localGitStatus) {
        Write-Host "📝 Local Action Plan changes detected:" -ForegroundColor Yellow
        git diff documentation/action_plan.md
        $confirmAction = Read-Host "`nInclude Action Plan changes in commit? (y/n)"
        if ($confirmAction -ne "y") { Write-Host "❌ Action Plan sync cancelled."; exit }
    } else {
        Write-Host "✅ Action Plan has no local changes." -ForegroundColor Green
    }
} else {
    Write-Host "⚠️ Action Plan file not found at $actionplan" -ForegroundColor Yellow
}

# --- Commit and push both files ---
Write-Host "`n📤 Preparing to commit and push changes..." -ForegroundColor Cyan
cd $repo
git add README.md
git add documentation/rulebook_homeassistant_1_1.md
git add documentation/action_plan.md
git commit -m "Sync Rulebook and Action Plan documentation"
git push

Write-Host "`n✅ Sync complete! Rulebook + Action Plan pushed to GitHub." -ForegroundColor Green
