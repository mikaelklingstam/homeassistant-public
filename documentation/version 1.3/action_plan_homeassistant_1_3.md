Last updated: 2025-11-15 01:33 (CET) — Authorized by ChatGPT

# ⚙️ Action Plan – HomeAssistant 1.3

**Purpose:**  
Define a structured build order for implementing, testing, and refining the full Home Assistant 1.3 system — ensuring stability, traceability, and full feature integration, while learning from mistakes in 1.0–1.2.

---

## 🧩 Phase 0 – Baseline & Git

**Goal:** Start 1.3 from a known-good configuration with clean version control.

1. Start from stable 3-month-old configuration snapshot.
2. Create `documentation/version 1.3/` and `rulebook_homeassistant_1_3.md`.
3. Initialize Git repository in `\\192.168.2.130\config` with proper `.gitignore`.
4. Use `rulebook_homeassistant_1_3.md` as the source for `README.md`.

*(Tasks 1–2 already completed.)*

---

## 🧩 Phase 1 – Foundation

**Goal:** Ensure stable platform, access, and structure.

1. Verify Home Assistant OS and Proxmox setup.
2. Verify backup routine in Proxmox.
3. Confirm config share mount (`\\192.168.2.130\config`) and permissions.
4. Setup VS Code (code-server) and Codex for development.
5. Connect to private GitHub repo and confirm push/pull workflow.

---

## ⚡ Phase 2 – Core Integrations

**Goal:** Bring in only the integrations needed for the 1.3 mission, with clean configuration.

1. Reintroduce critical integrations (Huawei, Easee, Nordpool, Verisure, etc.) one by one.
2. For each integration: document purpose, main entities, and dependencies.
3. Remove legacy or unused integrations from configuration.
4. **Task 11 – TBD (next integration/feature)** — planned placeholder; scope will be defined before implementation.

---

## 📊 Phase 3 – Sensors & Helpers

**Goal:** Define all template sensors, utility meters, and helpers required for energy optimization, logging, and automation logic.

1. Reuse successful sensors from 1.1/1.2, but only if they have a clear purpose.
2. Add Nordpool price planning sensors and any forecast-based helpers.
3. Add peak-shaving metrics, rolling averages, and budget sensors.
4. Validate all helpers are actively used by automations or dashboards.

---

## 🎨 Phase 4 – GUI / Dashboards

**Goal:** Build a clean, unified visual interface following the Visual & Control philosophy.

1. Create main energy flow dashboard (solar–battery–house–EV–grid).
2. Create control panels for battery, EV, and peak shaving.
3. Add settings/advanced views for thresholds and overrides.
4. Ensure all UI text is in English and scalable for desktop/mobile.

---

## 📜 Phase 5 – YAML Scripts

**Goal:** Centralize repeated sequences into scripts to simplify automations and manual control.

1. Reintroduce working YAML scripts from 1.2 (cleaned and documented).
2. Add scripts for:
   - EV charging strategy.
   - Battery charge/discharge control.
   - Export control (when/if allowed).
3. Document each script’s inputs, outputs, and related automations.

---

## 🤖 Phase 6 – Automations & Logic

**Goal:** Implement robust, testable automations for energy optimization, comfort, and safety.

1. Peak shaving logic (monthly peaks, 22:00–06:00 50% weighting, etc.).
2. Battery automations (charge from grid vs. solar, SOC limits, export rules).
3. EV charging automations, including `sensor.id4pro_charging_time_left`.
4. Comfort overrides and “opt-out” paths that are clearly visible in the UI.
5. Logging and notifications for unexpected states.

---

## 📂 Phase 7 – Documentation, Public Repo & Maintenance

**Goal:** Ensure the entire system is understandable, reproducible, and kept in sync.

1. Keep `rulebook_homeassistant_1_3.md` as the authoritative rulebook.
2. Maintain `HA_Integrations_and_Sensors_1_3.md` and `Functions_And_Settings_1_3.md`.
3. Sync rulebook to GitHub `README.md` via script.
4. Maintain public repo with sanitized docs and examples.
5. Periodically review for unused helpers, automations, and entities.

---

## ✅ Task Tracker

- [x] Task 1 – Rulebook & README
- [x] Task 2 – Git structure
- [x] Task 3 – Documentation skeleton
- [x] Task 4 – …
- [x] Task 5 – Git sync scripts
- [x] Task 6 – Reintroduce integrations
- [x] Task 7 – Nordpool (done)
- [x] Task 8 – Grid Meter / Import–Export (done)
- [x] Task 9 – Huawei Solar & LUNA2000 (done)
- [x] Task 10 – Easee EV + ID.4 (done)
- [ ] Task 11 – Pending
