Last updated: 2025-02-12 16:32 (CET) — Authorized by ChatGPT

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
4. **Task 11 – Integration #5 – Verisure (alarm, security & smart plugs)** — completed: Verisure entities grouped, customized, and documented in Task 11.
5. **Task 12 – Integration #6 – Weather & Environment** — completed: SMHI primary weather feed, Met.no backup, and Forecast.Solar forecasts normalized into the HA1 weather package and documentation.

---

## 📊 Phase 3 – Sensors & Helpers

**Goal:** Define all template sensors, utility meters, and helpers required for energy optimization, logging, and automation logic.

1. Reuse successful sensors from 1.1/1.2, but only if they have a clear purpose.
2. Add Nordpool price planning sensors and any forecast-based helpers.
3. Add peak-shaving metrics, rolling averages, and budget sensors.
4. Validate all helpers are actively used by automations or dashboards.
5. Use the `documentation/version 1.3/task14_template_sensor_framework_stub.md` checklist to drive Task 14 (template sensor framework & naming standard) so packages stay consistent.

### ✔️ Task 14 – Template Sensor Framework & Naming Standard

Task 14 introduces the HA1.3 template framework for power and flow measurements and connects it to a first control layer:

- Defined a normalized set of raw watt-based sensors (`sensor.ha1_raw_*`) for grid, solar, battery, EV, and the Huawei meter.  
- Built the canonical power layer (`sensor.ha1_power_*`) for grid net, solar AC, battery net, EV power, house total and house core consumption.  
- Added a basic flow layer (`sensor.ha1_flow_*`) for grid import/export, EV charging and battery discharge.  
- Implemented sanity checks for model balance and Huawei meter mismatch, plus binary flags for debugging.  
- Created the HA1 Debug dashboard view with snapshots, sanity information, 1h/24h history graphs and a Control Tools section.  
- Introduced the HA1 control layer for Huawei battery and Easee EV charger, including master automation toggles, tuning sliders and helper scripts.

### ✔️ Task 15 – Sensor Layer / Template Sensors & Rolling Metrics

Task 15 finishes the sensor/helper foundation by layering planning-friendly metrics on top of the Task 14 framework:

- `packages/energy_core_1_3.yaml` now exposes canonical HA1 power/flow signals for solar → house/grid, battery → house/grid, and EV load so every downstream consumer uses the same sign conventions.  
- `packages/energy_metrics_1_3.yaml` converts the raw W-based channels into human-scale kW summaries (`sensor.ha1_power_consumption_total_kw`, `sensor.ha1_power_net_load_kw`, etc.), peak-limit helpers, and EV share KPIs.  
- Statistics-based rolling averages (`sensor.ha1_power_house_total_avg_1m`, `sensor.ha1_flow_grid_import_avg_5m`, etc.) smooth noisy measurements for dashboards and guards.  
- The same package also surfaces the Huawei charge-limit numbers (`number.battery_grid_charge_maximum_power`, `number.battery_maximum_charging_power`) so automations know the physical caps before scheduling EV/battery activity.  
- Utility meters for grid import/export (daily + weekly) and the legacy `sensor.home_load` alias were refreshed to keep old dashboards working without extra YAML.

These deliverables close Phase 3 so Task 16 can introduce helper-driven behavior without reworking sensors again.

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

### Peak Shaving Automations – Phase 1

**Purpose:**  
Prevent monthly peak overruns by coordinating EV charging and battery grid-charging behavior when net grid power approaches the configured limit.

**Inputs / Helpers:**
- `input_number.ha1_peak_limit_kw` – hard monthly peak limit (kW)
- `input_number.ha1_peak_warning_margin_kw` – warning zone margin (kW)
- `sensor.ha1_net_grid_power` – net grid import (W, positive = import)
- Guardrails:
  - `input_boolean.ha1_automations_master_enable`
  - `input_boolean.ha1_peak_shaving_enabled`
  - `input_boolean.ha1_ev_automation_enabled`
  - (later) `input_boolean.ha1_battery_automation_enabled`

**Zones & thresholds:**
- **Warning threshold:** `(peak_limit_kw - margin_kw)`
- **Hard limit:** `peak_limit_kw`
- All thresholds are internally converted to watts.

**Dwell times:**
- Warning zone: above warning threshold for **1 minute**
- Hard breach: above hard limit for **1 minute**
- Recovery: below warning threshold for **5 minutes**

**Behavior Model:**
1. **Normal zone**  
   - No peak intervention.  
   - EV/battery follow normal automation rules.

2. **Warning zone**  
   - EV charging is paused to slow the climb toward peak (soft protection).  
   - Battery grid-charging suppression planned but not forced in Phase 1.

3. **Hard breach**  
   - EV charging must be paused.  
   - Battery grid-charging OFF hook included (script id to be wired in once confirmed).

4. **Recovery**  
   - Once grid power remains below the warning threshold for 5 minutes, protection lifts.  
   - EV/battery optimization is allowed to resume when their own logic permits.

**Logging & Observability:**
- Every intervention writes a log entry via `logbook.log` with name `"HA1 Peak"`.  
- Messages include actual grid power and configured peak limit.

**Phase Status:**  
Phase 1 provides a robust and safe foundation for peak shaving using EV control as the primary lever.  
Battery grid-charge suppression will be fully implemented in Phase 2.

---

## 📂 Phase 7 – Documentation, Public Repo & Maintenance

**Goal:** Ensure the entire system is understandable, reproducible, and kept in sync.

1. Keep `rulebook_homeassistant_1_3.md` as the authoritative rulebook.
2. Maintain `HA_Integrations_and_Sensors_1_3.md` and `Functions_And_Settings_1_3.md`.
3. Sync rulebook to GitHub `README.md` via script.
4. Maintain public repo with sanitized docs and examples.
5. Periodically review for unused helpers, automations, and entities.
6. **Pre-Task 13 doc sync (2025-11-15 17:50 CET):** Rulebook, action plan, integrations/sensors, and functions/settings reviewed and timestamped so the baseline is ready for the next task.

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
- ✅ Task 11 – Integration #5: Verisure (alarm, locks, perimeter sensors, smart plugs, environment) added, grouped, and documented.
- ✅ Task 12 – Integration #6: Weather & Environment (SMHI primary provider, Met.no backup, Forecast.Solar documented for PV planning).
- [x] Task 14 – Template Sensor Framework & Naming Standard (completed; see Task 14 summary above).
- ✅ Task 15 – Sensor Layer / Template Sensors & Rolling Metrics (canonical `ha1_*` flows, kW rollups, statistics smoothing, and Huawei charge-limit mirrors).

### ✅ Task 18 – Diagnostics & Status Layer

- Implemented HA1 diagnostics groups (grid, solar/battery, EV, prices, peaks, helpers).
- Added HA1 system status sensors for at-a-glance behaviour.
- Introduced HA1 logging helper scripts for structured Logbook events.
- Verified and fixed all HA1 Debug / Energy entity references.

### ✅ Task 22 – EV Charging Automations (Phase 3)
- EV price-threshold sliders added (`ha1_ev_price_cheap_max`, `ha1_ev_price_normal_max`, `ha1_ev_price_expensive_max`).
- EV price-level derived sensor added (`sensor.ha1_ev_price_level`).
- Automations updated to cheap_only/balanced/aggressive logic with peak and very-expensive guards.
- Cheap-only & time-critical fallback finalized; balanced/aggressive scaffolds documented.

### ☐ Task 23 – EV charging — Phase 2 automation refinement (runtime tuning & edge cases)

### ✅ Task 25 – Comfort Overrides & Exception Handling (Phase 1)
- Comfort override toggle, timer, duration helper and dashboards added; EV price gating/very-expensive pause and peak shedding respect comfort override.
- Auto-expire/cleanup automations log enable/disable/expiry; debug/testing tools added for effective price override checks.
