# Home Assistant Public Export

This repository is a sanitized mirror of the automations, dashboards, documentation, and helper packages from my private Home Assistant configuration. Anything containing secrets (credentials, device tokens, etc.) stays in the private repo; every file here is safe to share.

## What’s Included
- `documentation/` – process docs, inventory, rulebooks
- `dashboards/` – Lovelace dashboards managed in YAML
- `packages/` – reusable helpers for energy, schedules, pets, etc.
- `scripts/` – shareable PowerShell helpers (includes `sync-ha-and-public.ps1`)
- `automations.yaml` – Home Assistant automations with sensitive values referenced via `!secret`
- `scripts.yaml` – HA scripts that likewise load sensitive data from `!secret`

Nothing outside this list is exported. Secrets referenced with `!secret` continue to live only in `secrets.yaml` inside the private repo.

## Sync Process
`scripts/sync-ha-and-public.ps1` keeps this mirror fresh by:
1. Staging/committing/pushing changes in the private repo.
2. Copying the directories/files above into this repo.
3. Using the same commit message on both sides.

Conflicts are handled interactively (or automatically with `-ConflictPolicy UsePrivate`).

## Feedback / Issues
Open an issue or PR here if you spot broken docs or missing information. Configuration-specific questions belong in the private repo, but documentation fixes are welcome.
