# sync-ha-and-public.ps1

PowerShell helper that keeps the private Home Assistant repo and the public mirror in sync. Supports Windows, Linux, and code-server shells.

## Installation
The script lives at `scripts/sync-ha-and-public.ps1`. No additional modules are required beyond Git and PowerShell 7+.

## Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-HomeRoot` | String | auto-detect | Optional path to the private repo. Auto-detection checks `$env:HOMEASSISTANT_HOME`, the provided value, and common folders. |
| `-PublicRoot` | String | auto-detect | Optional path to the public repo. Auto-detection checks `$env:HOMEASSISTANT_PUBLIC`, the provided value, and common folders. |
| `-Message` | String | prompt | Commit message used for both repos. If omitted, you’ll be prompted (or a timestamp default is used in automated modes). |
| `-SyncPublic` | Switch | Off | When set, mirror selected folders/files into the public repo after updating the private repo. |
| `-SkipPublic` | Switch | Off | When set, only update the private repo. Mutually exclusive with `-SyncPublic`. |
| `-ConflictPolicy` | Prompt/UsePrivate/KeepPublic/Abort | Prompt | Determines how to handle public-repo edits inside synced folders/files when syncing. `Prompt` asks per file, `UsePrivate` always overwrites with private copy, `KeepPublic` preserves existing public edits, `Abort` stops the sync if any conflicts exist. |

## Exported content
When `-SyncPublic` is used, these paths are mirrored:
- `documentation/`
- `dashboards/`
- `packages/`
- `scripts/`
- `automations.yaml`
- `scripts.yaml`

## Usage Examples
### Basic private sync only
```powershell
pwsh -File scripts/sync-ha-and-public.ps1 -SkipPublic
```

### Full sync with custom commit message
```powershell
pwsh -File scripts/sync-ha-and-public.ps1 \
  -Message "chore: export dashboards" \
  -SyncPublic
```

### CI/non-interactive mode (overwrite public changes)
```powershell
pwsh -File scripts/sync-ha-and-public.ps1 \
  -HomeRoot "$env:GITHUB_WORKSPACE" \
  -PublicRoot "$env:GITHUB_WORKSPACE\public" \
  -Message "ci: nightly export" \
  -SyncPublic \
  -ConflictPolicy UsePrivate
```

### Keep public edits when conflicts arise
```powershell
pwsh -File scripts/sync-ha-and-public.ps1 \
  -SyncPublic \
  -ConflictPolicy KeepPublic
```

### Abort automatically when conflicts exist
```powershell
pwsh -File scripts/sync-ha-and-public.ps1 \
  -SyncPublic \
  -ConflictPolicy Abort
```

### Run from anywhere via absolute path
```powershell
$scriptPath = Resolve-Path "$HOME/homeassistant/scripts/sync-ha-and-public.ps1"
pwsh -NoLogo -NoProfile -Command "& '$scriptPath' -Message 'chore: export' -SyncPublic -ConflictPolicy Prompt"
```
Substitute the first line with the absolute path to your repo so the second command works no matter which directory you’re currently in.

## Tips
- Store paths in env vars (`HOMEASSISTANT_HOME`, `HOMEASSISTANT_PUBLIC`) to avoid passing `-HomeRoot/-PublicRoot`.
- If the public repo is outside the workspace or requires elevation, run the script with the necessary permissions before syncing.
- The script prints each conflicting file when using `-ConflictPolicy Prompt`, allowing you to decide per item whether to keep public edits or overwrite with private state.
- Add `pwsh -File scripts/sync-ha-and-public.ps1 -SyncPublic -ConflictPolicy UsePrivate` to a scheduled task/cron job for unattended exports.
