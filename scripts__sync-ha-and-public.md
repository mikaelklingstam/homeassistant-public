# sync-ha-and-public.ps1

PowerShell helper that keeps the private Home Assistant repo and the public mirror in sync. Supports Windows, Linux, and code-server shells.

## Installation
The script lives at `scripts/sync-ha-and-public.ps1`. No additional modules are required beyond Git and PowerShell 7+.

## Parameters
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-HomeRoot` | String | auto-detect | Optional path to the private repo. If provided, it must exist. Otherwise the script probes `$env:HOMEASSISTANT_HOME` first, then common folders. |
| `-PublicRoot` | String | auto-detect | Optional path to the public repo. If provided, it must exist. Otherwise the script probes `$env:HOMEASSISTANT_PUBLIC` first, then common folders. |
| `-Message` | String | prompt/default | Commit message used for both repos. If omitted, you’ll be prompted and an empty response falls back to a timestamped default. |
| `-UseDefaultMessage` | Switch | Off | Skip the prompt and always use the timestamped default message (useful for automation without supplying `-Message`). |
| `-SyncPublic` | Switch | Off | When set, mirror selected folders/files into the public repo after updating the private repo. |
| `-SkipPublic` | Switch | Off | When set, only update the private repo. Mutually exclusive with `-SyncPublic`. |
| `-ConflictPolicy` | Prompt/UsePrivate/KeepPublic/Abort | Prompt | Determines how to handle public-repo edits inside synced folders/files when syncing. `Prompt` asks per file, `UsePrivate` always overwrites with private copy, `KeepPublic` preserves existing public edits, `Abort` stops the sync if any conflicts exist. |

## Exported content
When `-SyncPublic` is used, these private paths are exported (subject to secret scanning):
- `documentation/`
- `dashboards/`
- `packages/`
- `scripts/`
- `automations.yaml`
- `scripts.yaml`
- `README.md` (generated automatically if the public repo does not have one)

The public repo cannot expose subfolders, so every exported file is flattened into the repository root using double underscores between folder segments. Example:

```
documentation/version 1.3/Functions_And_Settings_1_3.md
   → documentation__version_1.3__Functions_And_Settings_1_3.md
```

A manifest file named `.sync-public-index.json` is written at the root of the public repo so the script knows which flattened files it manages between runs.

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
  -UseDefaultMessage \
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
- Combine `-UseDefaultMessage` with `-SyncPublic` for unattended runs when you don’t care about a custom commit title.
- If the public repo is outside the workspace or requires elevation, run the script with the necessary permissions before syncing.
- The script prints each conflicting file when using `-ConflictPolicy Prompt`, allowing you to decide per item whether to keep public edits or overwrite with private state.
- Add `pwsh -File scripts/sync-ha-and-public.ps1 -SyncPublic -ConflictPolicy UsePrivate` to a scheduled task/cron job for unattended exports.
