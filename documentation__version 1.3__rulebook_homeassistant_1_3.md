Last updated: 2025-11-17 15:53 (CET) — Authorized by ChatGPT

# 🧭 HomeAssistant 1.3 – Rulebook

## 📘 General Info (Priority 1)

Installation method  
Home Assistant OS  
Core 2025.11.1  
Supervisor 2025.11.1  
Operating System 16.3  
Frontend 20251105.0  

Installed on Proxmox via https://github.com/tteck/Proxmox  
Config directory: \\192.168.2.130\config  

This rulebook describes **HomeAssistant 1.3**, built from a stable configuration snapshot (~3 months old) to avoid legacy broken helpers, automations, and integrations from versions 1.0–1.2.

All dashboards and UI text must be written in **English**.

---

## 🧭 Mission (Priority 1)

Create an intelligent, self-learning, and fully integrated home system where energy optimization, safety, and comfort work together automatically. The system continuously adapts to electricity prices, peak charges, availability, weather, and presence to minimize cost, maximize efficiency, and improve quality of life — without manual control. With clearly defined boundaries, it functions like a self-playing piano that learns from historical data and version 1.x experiences.

---

## 📦 Versioning & Scope

- **Version:** HomeAssistant 1.3  
- **Baseline:** Clean configuration from ~3 months ago (before broken helpers/automations accumulated).  
- **Goal:** Reach the same functional end state as the 1.2 design, but:
  - With only active, used helpers and automations.
  - With clearer structure for documentation, Git, and public/private separation.
  - With all decisions and contradictions logged in this rulebook.

1.0 and 1.1 act as knowledge/reference; 1.2 acts as the **design target**. 1.3 is the implementation that reaches that target cleanly.

---

## ⚙️ Structure of HomeAssistant 1.3

Configuration and documentation are organized by the following layers (which will also shape this rulebook):

1. **Integrations**  
2. **Sensors & Helpers**  
3. **GUI / Dashboards**  
4. **YAML Scripts**  
5. **Automations & Logic**

Each layer will be documented with:
- Purpose  
- Entities (inputs/outputs)  
- Dependencies  
- Known limitations / TODOs  

---

## ⚙️ Integrations (Overview – Priority 1)

> Detailed entity lists will live in `HA_Integrations_and_Sensors_1_3.md`.  
> This section will later summarize the *role* of each integration in the 1.3 system (Huawei, Easee, Verisure, Nordpool, etc.).

- **Nordpool Electricity Prices — SE3, SEK, incl. VAT**
  - Status: Active & verified for HomeAssistant 1.3
  - Method: GUI integration only
  - Notes: All previous YAML planners and cheapest-hours logic removed in Task 7.
- **Huawei Solar & LUNA2000 (PV + Battery)**
  - Status: Canonical PV + battery integration for 1.3
  - Provides inverter power, battery SOC, charge/discharge power, and Huawei power meter values.
  - All downstream logic consumes the normalized HA1 layer (kW, %, unified sign conventions) exposed by `packages/huawei_solar_1_3.yaml`.
- **Grid Meter / Import–Export (Integration #2)**
  - Canonical grid source: Easee P1 meter (`QP57QZ4Q`)
  - Net power sensor: `sensor.grid_import_export_power`
  - Sign: **+ import, – export** (kW)
  - Huawei power meter kept as diagnostic source only.
- **Verisure – Alarm, Security & Smart Plugs (Integration #5)**
  - Provides the primary alarm panel state, front-door Lockguard control, perimeter door/window sensors, selected temperature/humidity feeds, and several Verisure smart plugs (touch display, bedroom, hallway, office, etc.).
  - These entities support safety (alarm notifications, auto-lock/unlock), comfort automations (lighting scenes, display power), and environmental monitoring.
- **Weather & Environment (Integration #6)**
  - SMHI (`weather.smhi_home`) supplies the primary weather feed, Met.no (`weather.home` / `weather.home_hourly`) remains configured as a backup provider, and Forecast.Solar delivers PV production forecasts.
  - Canonical HA1 weather sensors live in `packages/weather_environment_1_3.yaml`; Forecast.Solar entities are documented but not yet consumed by automations (reserved for future PV/battery planning).

**Global sign conventions (applies system-wide):**
- Grid power: `+` = importing from grid, `-` = exporting to grid (kW).
- Huawei battery power: `+` = charging, `-` = discharging (kW).
- All HA1 power sensors report **kW**; HA1 energy sensors report **kWh**.

### Easee EV Charger & Equaliser Control (1.3)

The Easee ecosystem in HomeAssistant 1.3 is split into two distinct control layers:

1. **Equaliser / Circuit level**
   - The Easee Equaliser supervises the main fuse (or a dedicated sub-fuse group).
   - It manages the **circuit dynamic limit** – the maximum current that all connected chargers on that circuit are allowed to draw in total.
   - This corresponds to the Easee API / HA service `easee.set_circuit_dynamic_limit` (and its per-phase variants).
   - The Equaliser ensures the configured limit and fuse size are respected, regardless of what individual chargers try to draw.

2. **Charger level (ID.4 charger)**
   - The Easee charger itself controls the actual charging current for the EV.
   - It obeys a **charger dynamic limit** – a per-charger maximum current.
   - This corresponds to the service `easee.set_charger_dynamic_limit`.
   - The charger can never exceed:
     1) the circuit limit from the Equaliser, and
     2) its own charger dynamic limit.

#### Hierarchy

The practical hierarchy in 1.3 is:

> **Grid / Main fuse → Equaliser circuit limit → Charger dynamic limit → Actual EV charging current**

- The Equaliser/circuit limit is the **safety ceiling** for the entire fuse group.
- The charger limit is the **strategy ceiling** for that specific charger within the circuit.

#### Design rules for 1.3

1. **Circuit dynamic limit = safety and fuse protection**
   - `easee.set_circuit_dynamic_limit` is treated as a **protection and safety control**, not a high-frequency optimization knob.
   - It may be adjusted by automations only when necessary to:
     - Respect main-fuse comfort margins.
     - Prevent overload when total house load is high.
     - Provide a “last line of defence” if other optimizations fail.
   - The circuit limit should change relatively rarely and conservatively.

2. **Charger dynamic limit = optimization knob**
   - `easee.set_charger_dynamic_limit` is the **primary control variable** for EV charging strategy.
   - It is allowed to change more frequently (within reasonable limits) based on:
     - Nordpool price levels and cheapest hours.
     - Solar production vs house load.
     - Huawei battery SOC and charge/discharge strategy.
     - Peak-shaving constraints defined in the 1.3 rulebook.
   - Examples:
     - Cheapest hours → higher charger limit (e.g. 16–20 A).
     - Expensive hours → reduced limit (e.g. 6–8 A) or complete stop.
     - High solar excess and good battery SOC → increase limit to absorb surplus.
     - High grid import or low battery SOC → reduce or pause EV charging.

3. **Schedules and overrides**
   - The Easee schedule (configured in the app) is treated as a **baseline behaviour**.
   - HomeAssistant 1.3 may override the schedule when necessary:
     - Using the charger enable/disable entity (e.g. `switch.ehxdyl83_charger_enabled`) to start/stop charging.
     - Using the override button (e.g. `button.ehxdyl83_override_schedule`) when an immediate start is required outside the normal schedule.
   - The rulebook logic layer must respect that:
     - **Equaliser circuit limit** always has the final say on how much current is available.
     - **EV optimization logic** (price, solar, battery, peaks) operates via the charger dynamic limit and start/stop decisions.

4. **Integration with the HA1.3 energy model**
   - Template sensors in the HA 1.3 namespace (`sensor.ha1_*`) are responsible for:
     - Representing PV → Grid, Battery → House, Grid → House/EV, and peak tracking.
     - Tracking relevant cost and comfort constraints (Nordpool windows, peak limits, minimum SOC).
   - EV charging strategies must:
     - Always stay within the Equaliser’s circuit limit and main-fuse assumptions.
     - Use charger dynamic limit and start/stop as the primary tools to implement the optimization logic defined in this rulebook.
   - This ensures that the Easee Equaliser continues doing its built-in load balancing job, while the 1.3 energy logic adds an extra optimization layer on top without fighting the hardware.

---

## 🧪 Sensors & Helpers (Overview)

The HA1 template/helper stack is now live after Task 15 and is split into two layers:

1. `packages/energy_core_1_3.yaml` – Canonical **W**-based flow sensors (`sensor.ha1_power_*`, `sensor.ha1_flow_*`) that represent solar → house/grid, battery → house/grid, EV load, and the grid meter (`sensor.ha1_power_grid_total_net`). These must be the only sources used for optimization logic, dashboards, and plotting when discussing instantaneous power.
2. `packages/energy_metrics_1_3.yaml` – Planning metrics on top of the core flows: `sensor.ha1_power_consumption_total_kw`, `sensor.ha1_power_net_load_kw`, peak helpers (`sensor.ha1_effective_peak_power_reference_kw`, `sensor.ha1_peak_margin_kw`), EV share KPIs, Huawei charge-limit mirrors, and the statistics-based rolling averages (`sensor.ha1_power_house_total_avg_1m`, `sensor.ha1_flow_grid_export_avg_5m`, etc.).

**Rules of engagement**

- Peak logic, EV/battery schedulers, and dashboards must read **kW** abstractions (`*_kw`) for human-facing displays, but always use the **raw W channels** for precise math if sub-1 kW accuracy is required.  
- When judging stability or anti-flapping thresholds, prefer the rolling-average entities instead of the instantaneous raw sensors. Any guard that needs “sustained high import/export” should reference `sensor.ha1_power_grid_net_avg_*` or the 1‑minute house/EV averages.  
- Historical meters and billing logic must consume the HA1 utility meters:
  - Import/export daily + weekly counters live in `packages/ev_charging_1_3.yaml` as `sensor.ha1_grid_import_energy_daily`, etc.
  - Legacy dashboards expecting `sensor.home_load` or similar must keep using the provided compatibility aliases (maintained inside `energy_metrics_1_3.yaml`).
- Helper values (sliders/toggles) that drive this layer are centralized in `packages/helpers_1_3.yaml`. Any automation referencing peak limits, SOC thresholds, or override flags must use the `ha1_*` helpers so UI + documentation remain aligned.

**Task 16 helpers consolidation:** All HA1.3 helper entities now live in `packages/helpers_1_3.yaml`, follow the `ha1_` prefix, and replace every legacy 1.1/1.2 helper unless that helper is still explicitly referenced. This keeps dashboards, scripts, and documentation synchronized around a single helpers layer.

The objective is simple: **never** template raw vendor sensors twice. All logic must work off the HA1 namespace so charting, diagnostics, and automation math stay in sync.

---

## 🎨 GUI / Dashboards (Overview)

> Visual & Control philosophy, energy flow view, control panels, and settings/config views.

*(To be filled in later tasks.)*

---

## 📜 YAML Scripts (Overview)

> Home Assistant scripts (scripts.yaml) and external PowerShell helpers (scripts folder).

*(To be filled in later tasks.)*

---

## 🤖 Automations & Logic (Overview)

> Core automations for:  
> - Peak shaving  
> - Battery charge/discharge  
> - EV charging (including `sensor.id4pro_charging_time_left`)  
> - Comfort overrides  
> - Export logic and price-driven strategies  

*(To be filled in later tasks.)*

---

## 📚 Documentation & Public Repo

- This file (`rulebook_homeassistant_1_3.md`) is the **authoritative rulebook** for HomeAssistant 1.3.  
- The **public repo README** will mirror this file (content-wise) so external viewers see the same information as here, but without any secrets.

Further documentation for 1.3 will be placed in:
- `documentation/version 1.3/action_plan_homeassistant_1_3.md`  
- `documentation/version 1.3/HA_Integrations_and_Sensors_1_3.md`  
- `documentation/version 1.3/Functions_And_Settings_1_3.md`  

If you edit this file again yourself, remember: update the **Last updated:** line at the top.

### Task 18 – Diagnostics, Status & Logging

- Introduced HA1 diagnostics groups for grid, solar/battery, EV, prices, peaks and helpers.
- Added HA1 system status sensors (price level, peak near limit, EV/battery short states).
- Created HA1 logging helper scripts for peak, price, EV, battery and override events.
- Cleaned up legacy groups and aligned HA1 Debug dashboard entities with the canonical HA1 sensors.
