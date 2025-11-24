Last updated: 2025-02-12 16:32 (CET) — Authorized by ChatGPT

# ⚙️ Functions & Settings – HomeAssistant 1.3

**Purpose:**  
Describe how the main functions of HomeAssistant 1.3 behave, which settings control them, and which entities they depend on. This is the “how it works” document for future you.

---

## Automation Framework & Safety Guardrails

### HA1.3 Automation Framework & Safety Guardrails

- All HA1.3 automations use a **global master toggle**:
  - `input_boolean.ha1_automations_master_enable`
- Domain-level toggles:
  - EV automations: `input_boolean.ha1_ev_automation_enabled`
  - Battery automations: `input_boolean.ha1_battery_automation_enabled`
  - Peak shaving: `input_boolean.ha1_peak_shaving_enabled`
  - Comfort override: `input_boolean.ha1_comfort_override_enabled`
- Standard guard pattern:
  - EV automations: master **AND** EV toggle must be ON.
  - Battery automations: master **AND** battery toggle must be ON.
  - Peak automations: master **AND** peak toggle must be ON.
  - Core automations: startup and mode logging do **not** depend on master; debug/safety logic usually does.
- Core framework automations (in `packages/ha1_automations_core_1_3.yaml`):
  - `HA1 – Core: automations startup` logs when HA1 core automations come online after HA boot and records the current toggle states.
  - `HA1 – Core: mode/toggle change logger` logs enable/disable events for master, EV, battery, peak and comfort override toggles.
  - `HA1 – Core: debug snapshot logger` logs a compact snapshot of key HA1.3 energy values when `script.ha1_debug_log_system_state` is executed.
- Logging standard:
  - `logbook.log` with `name` prefixes: `HA1 Core`, `HA1 EV`, `HA1 Battery`, `HA1 Peak`, `HA1 Debug`.
  - Messages are short, English, and start with `HA1:` for easy filtering.

## 1. Peak Shaving

**Goal:**  
Limit monthly peak power while respecting comfort and necessary charging.

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

**Key concepts (to be detailed later):**
- Monthly peak tracking (top peaks per month).
- 22:00–06:00 **50% weighting** of power for peak billing.
- Maximum allowed peak target (`input_number`).
- Comfort overrides that may temporarily break the peak limit.

**Primary sensors from Grid Meter package (Task 8):**
- `sensor.grid_import_export_power` – signed kW value used for peak math (positive import / negative export).
- `sensor.grid_active_power` – magnitude-only kW reference for dashboards and guards.
- `sensor.qp57qz4q_import_energy` / `sensor.qp57qz4q_export_energy` – canonical daily/ monthly billing totals.

**Utility meter roll-ups (Task 15 additions):**
- `sensor.ha1_grid_import_energy_daily` / `sensor.ha1_grid_export_energy_daily` – daily import/export counters derived from the canonical Easee meter totals. Used for dashboards, reports, and quick telemetry checks before billing data arrives.
- `sensor.ha1_grid_import_energy_weekly` / `sensor.ha1_grid_export_energy_weekly` – weekly versions of the above, intended for future budget/alert automations (e.g., Task 16 peak monitoring).

**Controlled by (planned):**
- Peak target slider(s).
- Booleans for:
  - “Peak shaving enabled”
  - “Allow comfort override”
- Related sensors from grid meter and utility meters.

## Peak Control & Effect Tariff (HA 1.3)

### Peak helpers and tariff inputs (HA 1.3)

| Entity ID                                       | Type          | Description |
|-------------------------------------------------|---------------|-------------|
| `input_select.ha1_peak_interval_mode`          | input_select  | Selects whether peak calculation uses hourly or 15-minute intervals. Options: `"hour"`, `"15min"`. |
| `input_number.ha1_daily_peak_power_cost_adjusted` | input_number | Highest interval power (cost-adjusted) for the current day. |
| `input_number.ha1_month_peak_top1_kw`          | input_number  | Highest daily peak (kW) in the current month. |
| `input_number.ha1_month_peak_top2_kw`          | input_number  | Second-highest daily peak (kW) in the current month. |
| `input_number.ha1_month_peak_top3_kw`          | input_number  | Third-highest daily peak (kW) in the current month. |
| `input_number.ha1_peak_tariff_price_per_kw`    | input_number  | Peak tariff price (SEK/kW). |
| `input_text.ha1_peak_tariff_agreement_name`    | input_text    | Agreement identifier/name (metadata only). |

**Ellevio effect tariff logic (HA 1.3)**  
Peak billing is calculated as:  
1. Determine average import power per interval (1 hour or 15 min).  
2. Apply 50% weighting between 22:00–06:00.  
3. Track the highest interval per day (cost-adjusted).  
4. Take the highest 3 days of the month.  
5. Final billed peak = average of those 3 values.

This section defines all helpers and sensors needed to support that logic.

---

## 2. Price-Driven Logic (Nordpool)

**Goal:**  
Use dynamic electricity prices to schedule consumption and charging.

**Key concepts:**
- Hourly Nordpool SE3 prices.
- Classification of “cheap”, “normal”, and “expensive” hours.
- Cheapest-hours planning windows.

**Primary price feed (Task 7):**
- `sensor.nordpool_kwh_se3_sek_3_10_025` – UI-managed Nordpool sensor whose `current_price` attribute drives all logic.

**Controlled by (planned):**
- Price threshold `input_number`s or presets.
- Time window selectors (e.g., “optimize next 24h”).

---

## 3. Battery Control (Huawei LUNA2000)

**Goal:**  
Use the battery to:
- Reduce peaks.
- Shift consumption from expensive to cheap hours.
- Avoid exporting solar when the battery still needs charging.

**Key concepts:**
- Minimum SOC for normal operation.
- Separate SOC thresholds for:
  - Peak shaving reserve.
  - Comfort/backup reserve.
- Grid-charging rules vs. solar-only charging.

**Core Huawei references (Task 9):**
- `sensor.ha1_huawei_battery_soc` – SOC for all thresholds.
- `sensor.ha1_huawei_battery_power` – signed kW for charge/discharge logic (positive = charging).
- `sensor.ha1_huawei_solar_power` – PV power reference when coordinating with price or peak logic.

## 🧠 HA1 Battery Automations – Phase 1 (Task 23)

**Purpose**  
Provide safe, deterministic baseline control for the Huawei LUNA2000 battery before introducing forecasting, AI-driven scheduling, or price-optimized strategies.

### Min SOC Protection

The battery is protected by two SOC thresholds:

- **Normal minimum SOC**: `input_number.ha1_battery_min_soc_normal`
- **Peak minimum SOC**: `input_number.ha1_battery_min_soc_peak`

Behavior:

- When SOC drops below the **normal minimum**, the system writes a logbook entry and the battery should not be used for non-essential optimizations.
- When SOC drops below the **peak minimum** while peak shaving is enabled, the system writes a logbook entry indicating that the battery should no longer be used for peak shaving.
- Phase 1 does not directly force Huawei to stop discharging; instead, all future peak/price/export automations must check SOC against these thresholds and must not intentionally drive SOC below them.

### Grid Charging Control

Grid charging is controlled via:

- `input_boolean.ha1_battery_allow_grid_charge`
- `input_number.ha1_battery_max_soc_charging`
- The following scripts:
  - `script.ha1_battery_allow_grid_charge_on`
  - `script.ha1_battery_allow_grid_charge_off`
  - `script.ha1_battery_apply_grid_charge_limit`

Behavior:

- When `input_boolean.ha1_battery_allow_grid_charge` is turned **on**, the system:
  - Calls `script.ha1_battery_allow_grid_charge_on`.
  - Calls `script.ha1_battery_apply_grid_charge_limit` to apply the configured grid charge power limit (within Huawei’s constraints).
  - Writes a logbook entry under the name **“HA1 Battery”**.
- When `input_boolean.ha1_battery_allow_grid_charge` is turned **off**, the system:
  - Calls `script.ha1_battery_allow_grid_charge_off`.
  - Writes a logbook entry indicating that grid charging was disabled.
- When the battery SOC reaches or exceeds `input_number.ha1_battery_max_soc_charging`, an automation:
  - Calls `script.ha1_battery_allow_grid_charge_off`.
  - Logs that grid charging was stopped at the configured target SOC.

### “No Export While Battery Needs Charge” (Phase 1 Observability)

The system monitors whether the battery still “needs charge” while export is happening.

- The battery is considered to **need charge** when:
  - `sensor.ha1_huawei_battery_soc` is below `input_number.ha1_battery_max_soc_charging`.
- Export is detected when either:
  - `sensor.ha1_flow_solar_to_grid` is greater than ~300 W, or
  - `sensor.ha1_net_grid_power` is less than –300 W (net export to grid).

In this Phase 1 implementation:

- A periodic automation (every 5 minutes) checks these conditions.
- If export is happening while the battery SOC is still below the export target, it writes a logbook entry under **“HA1 Battery”** explaining that export is ongoing while the battery is not yet at its target SOC.
- No actuator changes are done yet in Phase 1; this is an observability layer. Future export/price strategies must respect this rule and avoid export while the battery still needs charge.

### Guardrails and Dependencies

All HA1 battery automations introduced in Task 23 respect the HA1 automation framework and only run when:

- `input_boolean.ha1_automations_master_enable` = **on**
- `input_boolean.ha1_battery_automation_enabled` = **on**

Additionally, many automations also respect:

- `input_boolean.ha1_debug_freeze_optimizers` = **off**  
  (When this debug flag is on, optimizers are allowed to pause.)

These guardrails keep the battery logic aligned with the general HA1.3 automation framework (Tasks 21–22) and make it easy to temporarily pause or globally disable HA1 automations.

---

## 4. EV Charging (Easee + ID.4)

**Purpose:** Provide the minimum data set required to implement smart EV charging that is aware of Nordpool prices, grid peaks, main fuse limits, and the Huawei LUNA battery.

### Core planning inputs

These entities must be available and stable before EV charging automations are enabled:

- `sensor.ev_charger_power` (kW)  
  Used to detect when the EV is charging and how much load it adds to the system.

- `binary_sensor.ev_is_charging`  
  Simplified “charging / not charging” flag for use in automations and dashboards.

- `sensor.ev_charging_time_left`  
  **Primary planning input.** Represents how much time is needed to complete charging according to the ID.4. Future logic will combine this with cheapest hours and peak limits to decide when to start.

- `sensor.ev_battery_soc`  
  Used to decide when charging is necessary and to avoid charging when the car is already “full enough”.

- `sensor.ev_estimated_range`  
  Optional but useful for comfort-based decisions (e.g., minimum range for next morning).

### Integration with grid and battery logic

- EV charging is modeled as a **positive load** via `sensor.ev_charger_power` (kW).
- Grid import/export follows the convention:
  - `sensor.grid_import_export_power` > 0 → importing from grid
  - `sensor.grid_import_export_power` < 0 → exporting to grid
- Huawei LUNA battery power uses a separate sign convention (discharge vs charge).
- The Energy Overview uses `input_number.ha1_ev_max_charging_power_kw` (4–11 kW) as a user-friendly slider. A conversion sensor `sensor.ha1_ev_max_charging_current` maps this to a safe amp value (6–16 A) based on the actual installation (3×230 V). All Easee control scripts use the amp sensor, not the kW slider, so the user gets a human-friendly kW slider while the charger only ever receives valid current values.
- Future automations will:
  - Limit EV charging current based on available capacity under the main fuse.
  - Shift charging to cheap/low-peak hours when `sensor.ev_charging_time_left` allows it.
  - Coordinate with LUNA battery charging/discharging to avoid unnecessary peaks.

## ⚙️ HA1 Control Layer (Task 14)

The HA1 control layer wraps Huawei battery and Easee charger controls behind consistent helpers and scripts.

### Master toggles

- `input_boolean.ha1_control_ev_auto` – Enable/disable EV charging automations.  
- `input_boolean.ha1_control_battery_auto` – Enable/disable battery optimization automations.

### Task 16 – Helpers & Control Inputs

All HA1.3 helper entities now live in `packages/helpers_1_3.yaml`. They are grouped by role so dashboards and automations reference the same canonical sliders, toggles, and mode selectors:

- **Global / Peak:** `input_boolean.ha1_automations_master_enable`, `input_boolean.ha1_peak_shaving_enabled`, `input_number.ha1_peak_limit_kw`, `input_number.ha1_peak_warning_kw`.
- **Battery controls:** `input_boolean.ha1_control_battery_auto`, `input_boolean.ha1_battery_allow_grid_charge`, `input_boolean.ha1_battery_peak_support_enabled`, `input_number.ha1_battery_min_soc_normal`, `input_number.ha1_batt_peak_shaving_soc`, `input_number.ha1_battery_max_soc_target`, `input_number.ha1_batt_grid_charge_max_kw`, `input_number.ha1_batt_grid_charge_cutoff_soc`, `input_boolean.ha1_force_battery_charge_from_grid_now`.
- **EV charging:** `input_boolean.ha1_control_ev_auto`, `input_boolean.ha1_ev_obey_peak_limit`, `input_boolean.ha1_force_ev_charge_now`, `input_number.ha1_ev_max_charging_power_kw`, `input_number.ha1_ev_limit_current_a`, `input_select.ha1_ev_charging_mode`.
- **Comfort overrides:** `input_boolean.ha1_comfort_override_enabled`, `input_boolean.ha1_allow_high_price_heating`.
- **Debug / diagnostics:** `input_boolean.ha1_debug_energy_logic`, `input_boolean.ha1_debug_notifications_enabled`, `input_boolean.ha1_debug_freeze_optimizers`.

Every helper uses the `ha1_` prefix, and no legacy helpers remain; anything not in this list has been deleted or renamed.

### Control targets (input_numbers)

| Helper | Description |
|--------|-------------|
| `input_number.ha1_ev_limit_current_a` | Target EV charging current in amps (A). Drives dynamic current limit for Easee. |
| `input_number.ha1_batt_grid_charge_max_kw` | Maximum allowed battery grid charging power (kW). |
| `input_number.ha1_batt_peak_shaving_soc` | Target SOC (%) used for peak-shaving strategies. |
| `input_number.ha1_batt_grid_charge_cutoff_soc` | SOC (%) at which grid charging of the battery should stop. |

### Control scripts – Huawei battery

These scripts wrap the writable Huawei battery entities:

- `script.ha1_batt_enable_grid_charge` – Turns on `switch.battery_charge_from_grid`.  
- `script.ha1_batt_disable_grid_charge` – Turns off `switch.battery_charge_from_grid`.  
- `script.ha1_batt_apply_peak_shaving_soc` – Writes `input_number.ha1_batt_peak_shaving_soc` into `number.battery_peak_shaving_soc`.  
- `script.ha1_batt_apply_grid_charge_cutoff_soc` – Writes `input_number.ha1_batt_grid_charge_cutoff_soc` into `number.battery_grid_charge_cutoff_soc`.  

## EV Charging Automations – Phase 1 (Task 22)

### Scope

Phase 1 implements a safe, price-aware EV charging baseline for the Easee charger + ID.4, using:

- Canonical HA1 sensors (power/flows, net grid, cheap-hours helper)
- EV-specific price classification
- Global + EV guardrails
- Core EV start/stop scripts from Task 20

Focus is on **start/stop logic**; power/current limiting is prepared via helpers but not yet automated.

---

### Modes & guardrails

**Control entities**

- `input_boolean.ha1_automations_master_enable`  
  Global master switch for all HA1 energy automations.  
  If `off`, EV automations do nothing.

- `input_boolean.ha1_ev_automation_enabled`  
  EV-specific automation switch.  
  If `off`, EV automations do nothing even if master is `on`.

- `input_select.ha1_ev_charging_mode`  
  EV charging mode selector:
  - `off` – no automatic start; user/scripts only.
  - `cheap_only` – **Phase 1 logic implemented** (see below).
  - `balanced` – reserved for Phase 2 (currently behaves like `manual`).
  - `aggressive` – reserved for Phase 2 (currently behaves like `manual`).
  - `manual` – no automatic start; user/scripts only.

In Phase 1, **only `cheap_only` has active automation logic**. All other modes effectively disable automatic start (but peak-limit pause still protects the system).

---

### Price logic for EV (absolute thresholds)

EV uses its own price classification based on **absolute SEK/kWh thresholds**, independent from the global price level sensor.

**Helpers (set on debug / maintenance dashboard)**

- `input_number.ha1_ev_price_cheap_max`  
  Max price for **cheap** (SEK/kWh).

- `input_number.ha1_ev_price_normal_max`  
  Max price for **normal** (SEK/kWh).

- `input_number.ha1_ev_price_expensive_max`  
  Max price for **expensive** (SEK/kWh).  
  Anything above this is treated as **very_expensive**.

**Derived EV price sensor**

- `sensor.ha1_price_current`  
  Base Nordpool price (SEK/kWh) for current hour.

- `sensor.ha1_ev_price_level`  
  EV-specific price classification:

  - `cheap` – `price <= ha1_ev_price_cheap_max`  
  - `normal` – `cheap_max < price <= normal_max`  
  - `expensive` – `normal_max < price <= expensive_max`  
  - `very_expensive` – `price > ha1_ev_price_expensive_max`

This sensor is used **only by EV automations**.  
Global logic continues to use `sensor.ha1_status_price_level` from the price/interval package.

---

### Other key inputs & sensors

- `sensor.ha1_net_grid_power_avg_2min`  
  2-minute average net grid power (W), used for peak-limit safety.

- `input_number.ha1_peak_limit_kw`  
  User-defined peak limit (kW). EV start logic uses an 80 % margin; pause logic triggers at (≥ limit).

- `sensor.ha1_ev_cheap_hours_remaining_24h`  
  Template sensor estimating how many **cheap hours** remain in the next 24 h (from now), based on the Nordpool today/tomorrow arrays. Used for the time-critical fallback.

- `sensor.id4pro_charging_time_left`  
  ID.4’s own estimate of remaining charging time. Parsed as `hours_left` and used both for “don’t start too late” logic and adaptive fallback.

- `sensor.ehxdyl83_status`  
  Easee charger status (`awaiting_start`, `ready_to_charge`, `charging`, etc.), used to decide if we can/should start or need to pause.

- `switch.ehxdyl83_charger_enabled`  
  Charger on/off state; used as an extra guard in start/stop conditions.

---

### Core EV scripts used

Automations **do not call Easee services directly**; they call HA1 EV scripts:

- `script.ha1_ev_start_charging_simple`  
  Simple “start charging now” behavior:
  - Enables the charger.
  - Can optionally press the Easee “override schedule” button (as implemented in Task 20).

- `script.ha1_ev_stop_charging_simple`  
  Simple “stop/pause charging” behavior:
  - Disables the charger.

Future phases may introduce scripts for current-limit control; Phase 1 explicitly uses only these start/stop scripts.

---

### Phase 1 behaviors

#### 1. Start charging in cheap hours (mode: cheap_only)

Automation: `ha1_ev_start_cheap_only`

**Active when:**

- `input_boolean.ha1_automations_master_enable = on`
- `input_boolean.ha1_ev_automation_enabled = on`
- `input_select.ha1_ev_charging_mode = cheap_only`
- EV is plugged in and **not charging**:
  - `sensor.ehxdyl83_status` in `['awaiting_start', 'ready_to_charge']`
  - `switch.ehxdyl83_charger_enabled = off`
- Peak margin is safe:
  - Use `sensor.ha1_net_grid_power_avg_2min` vs `input_number.ha1_peak_limit_kw`.
  - Only start if avg net power ≤ 80 % of the configured peak limit.

**Price & time-left logic:**

- Normal case: start when `sensor.ha1_ev_price_level = cheap`.
- “Time-critical” case: if ID.4 reports **≤ 3 hours** left (`sensor.id4pro_charging_time_left`) and price is `normal`, we allow start even if not cheap.
- We **never** start when EV price level is `expensive` or `very_expensive`.

**Action:**

- Call `script.ha1_ev_start_charging_simple`.
- Log to Activities via `logbook.log` with:
  - Mode
  - EV price level
  - Current Nordpool price.

---

#### 2. Pause charging on peak-limit breach

Automation: `ha1_ev_pause_on_peak_limit`

**Active when:**

- `input_boolean.ha1_automations_master_enable = on`
- `input_boolean.ha1_ev_automation_enabled = on`
- EV is **currently charging**:
  - `sensor.ehxdyl83_status = 'charging'`
  - `switch.ehxdyl83_charger_enabled = on`
- `sensor.ha1_net_grid_power_avg_2min >= input_number.ha1_peak_limit_kw * 1000`

This automation is **independent of EV mode** for safety: if peak limit is breached, EV charging is paused regardless of `cheap_only/aggressive/manual`.

**Action:**

- Call `script.ha1_ev_stop_charging_simple`.
- Log to Activities with:
  - Average net grid power
  - Configured peak limit.

---

#### 3. Adaptive time-critical fallback (cheap_only)

Automation: `ha1_ev_start_time_critical_adaptive`

This provides a “don’t miss departure” escape route for `cheap_only` mode.

**Active when:**

- Same guardrails as above:
  - Master and EV automation toggles = `on`
  - Mode = `cheap_only`
  - EV plugged in and not charging
  - Peak margin safe (≤ 80 % of peak limit)
- `sensor.id4pro_charging_time_left` is **valid** and parsed as `hours_left`.
- `sensor.ha1_ev_cheap_hours_remaining_24h` is valid and parsed as `cheap_hours`.
- Condition:  
  `hours_left > cheap_hours + 0.5`  
  (i.e. we no longer have enough cheap hours left, plus a small safety margin).
- Current EV price level is `normal`:
  - Not `cheap` (that case is handled by the cheap-only automation).
  - Not `expensive` or `very_expensive`.

**Action:**

- Call `script.ha1_ev_start_charging_simple`.
- Log to Activities with:
  - Mode
  - Charging time left
  - Cheap hours remaining (24h window)
  - EV price level.

---

### Unavailable / unknown sensors

- If `sensor.id4pro_charging_time_left` is `unknown`/`unavailable`:
  - Cheap-only start falls back to a **non-time-critical** path:
    - It will still start in cheap hours.
    - Time-critical fallback will not trigger until the sensor becomes valid again.
- If `sensor.ha1_ev_cheap_hours_remaining_24h` is `unknown`:
  - Adaptive fallback will not run (safety: we avoid guesses about the remaining cheap budget).

---

### Current & power limit preparation

Phase 1 **does not yet adjust charging power automatically**, but the following helpers are in place for future phases:

- `input_number.ha1_ev_max_charging_power_kw`  
- `input_number.ha1_ev_limit_current_a`

Future tasks will introduce scripts/automations that translate these into Easee current-limit commands, possibly coordinated with peak shaving and battery behavior.

---
- `script.ha1_batt_apply_grid_charge_limit` – Writes `input_number.ha1_batt_grid_charge_max_kw` into `number.battery_grid_charge_maximum_power`.  
- `script.ha1_batt_set_peak_shaving_mode` – Sets `select.battery_working_mode` to peak shaving mode.

These functions provide a simple, automation-friendly interface for future peak shaving and grid-charge strategies.

### Control scripts – Easee EV charger

These scripts wrap Easee action commands and dynamic limit services:

- `script.ha1_ev_start_charging` – Sends `easee.action_command` with `start` for the configured device_id.  
- `script.ha1_ev_stop_charging` – Sends `easee.action_command` with `stop`.  
- `script.ha1_ev_pause_charging` – Sends `easee.action_command` with `pause`.  
- `script.ha1_ev_resume_charging` – Sends `easee.action_command` with `resume`.  
- `script.ha1_ev_override_schedule` – Sends `easee.action_command` with `override_schedule`.  
- `script.ha1_ev_set_dynamic_current_from_helper` – Calls `easee.set_charger_dynamic_limit` with the current value from `input_number.ha1_ev_limit_current_a`.

All EV operations are funneled through these HA1 scripts so that future optimization logic changes only in one place.

## Core Energy Scripts (HA1.3)

### EV scripts

- `script.ha1_ev_start_charging_simple`  
  Starts Easee charging for the ID.4 using `easee.start`, overrides the local schedule so charging begins immediately, and ensures the charger is enabled. No price/peak conditions.

- `script.ha1_ev_stop_charging_simple`  
  Stops/pause charging using `easee.stop` if the charger is currently charging and then disables the charger switch. Used as the basic “stop now” primitive by automations and manual buttons.

### Battery scripts (Huawei LUNA2000)

- `script.ha1_battery_allow_grid_charge_on`  
  Enables grid charging for the Huawei battery via `switch.battery_charge_from_grid`. Used when cheap prices or planned charging windows should allow filling the battery from the grid.

- `script.ha1_battery_allow_grid_charge_off`  
  Disables grid charging from the grid. Used during peak shaving, export priority or manual override.

- `script.ha1_battery_apply_grid_charge_limit`  
  Reads `input_number.ha1_battery_grid_charge_limit_kw` (kW), converts it to watts, clamps to the Huawei limit (2500 W) and writes the result to `number.battery_grid_charge_maximum_power`.

### Peak / emergency scripts

- `script.ha1_peak_emergency_reduce_load`  
  Emergency load-shed action: stops EV charging, blocks battery grid charging and forces the battery grid-charge limit helper to 0 kW before applying it to the Huawei charge limit. Intended to be called when interval power exceeds the allowed peak margin.

### Debug scripts

- `script.ha1_debug_log_system_state_energy`  
  Sends a one-line snapshot of key HA1 energy values (grid, solar, battery, EV charger, available battery kWh and peak metrics) to the logbook for debugging and verification.

### Energy Overview – User Dashboard (HA1)

- Dashboard file: `dashboards/ha1_energy_overview.yaml`  
- Dashboard ID/key: `ha1-energy-overview`  
- Dashboard title/view: **HA1 – Energy Overview** (`path: ha1-energy-overview`, `icon: mdi:home-battery`)  
- Purpose: primary user-facing daily view of solar → battery → house → EV → grid, with status tiles for price level, peak proximity and comfort override.  
- Notes: includes entities for key helpers (EV/battery automation toggles, peak limit sliders) and mini histories for grid/solar/battery and Nordpool price.

### HA1 Debug – Energy & Peaks View

**Purpose**  
Technical / engineering dashboard used to inspect and debug the full HA1.3 energy stack: grid, solar, battery, EV, Nordpool price, peaks, helpers and diagnostics.

**Location**  
- Dashboard file: `dashboards/ha1_debug_energy.yaml`  
- Dashboard title: **HA1 Debug – Energy**  
- View: **Energy & Peaks** (`path: ha1-debug-energy`)

**What it exposes**

- **System Status**
  - `group.ha1_system_status` summary
  - Net grid power and automation posture (on/off helpers)
  - Battery SOC
  - EV charger power and ID.4 charging time left
  - Current Nordpool SE3 price

- **Grid & Peaks**
  - Net grid power (W/kW) and rolling load metrics
  - Import/export power and energy from the Easee Equalizer
  - Interval and monthly peak sensors, including:
    - billable peak load
    - reference peak
    - margin to peak
    - real and cost-adjusted interval power
    - monthly real and cost-adjusted peaks
    - estimated monthly peak cost

- **Solar & Battery**
  - PV AC production power (`sensor.ha1_power_solar_ac`)
  - Net battery power (`sensor.ha1_power_battery_net`)
  - Battery SOC
  - Key HA1 flow sensors such as `sensor.ha1_flow_battery_discharge`
  - 24-hour history graph for PV, battery power and SOC

- **EV / Easee**
  - Charger power and charger status
  - ID.4 charging time left
  - HA1 EV power/flow sensor(s) such as `sensor.ha1_power_ev_charger` and `sensor.ha1_flow_ev_charging_power`
  - 24-hour history graph of EV charging power

- **Price & Planning**
  - Nordpool SE3 price with HA1 helpers for:
    - current price
    - daily min/avg/max
    - price-level diagnostics (low/normal/high etc.)
  - 48-hour price history graph for planning and correlation with automations

- **Helpers & Modes**
  - Peak helpers: peak-shaving enable, interval mode, peak limit/warning, daily and monthly top-3 peaks, tariff price and agreement name
  - Battery helpers: automation enable, grid charge/peak-support flags, forced charge, SOC limits and grid-charge power/cut-off
  - EV helpers: automation enable, obey-peak flag, force-charge, EV charging mode, max power and current limit
  - Comfort/debug helpers: master automation enable, comfort override, high-price heating allowance, energy-logic debug flags, notification/debug freeze helpers

- **Diagnostic Groups**
  - `group.ha1_diag_grid`
  - `group.ha1_diag_solar_battery`
  - `group.ha1_diag_ev`
  - `group.ha1_diag_peaks`
  - `group.ha1_diag_helpers`
  - `group.ha1_diag_prices`
  - plus `group.ha1_system_status` for consolidated system status.

### Task 15 – Extended Power Metrics & Rolling Averages

All deliverables below live in `packages/energy_metrics_1_3.yaml` (templates + statistics) and consume the base HA1 flow sensors produced by `packages/energy_core_1_3.yaml`. Utility meters for grid import/export remain in `packages/ev_charging_1_3.yaml`, so every Task 15 concept has a clearly documented home.

- Combined load sensors now expose canonical W signals in kW for dashboards and planning logic:  
  - `sensor.ha1_power_consumption_total_kw` → total house consumption including EV load.  
  - `sensor.ha1_power_consumption_core_kw` → core load excluding the EV charger.  
  - `sensor.ha1_power_net_load_kw` and `sensor.ha1_power_net_load_abs_kw` → signed and absolute net grid load in kW.  
  - Legacy `sensor.home_load` is now a thin wrapper around `sensor.ha1_power_house_total`, so old dashboards automatically use the HA1 math.
- Rolling averages smooth noisy grid measurements using the `statistics` platform:  
  - Net grid power (`sensor.ha1_power_grid_total_net`) has both 1‑min and 5‑min averages for control logic.  
  - Import/export flow sensors (`sensor.ha1_flow_grid_import`, `sensor.ha1_flow_grid_export`) each gain 1‑min and 5‑min means for dashboards and guard conditions.

## HA1 Extended Template Metrics (Task 15)

These sensors form the “second layer” of HomeAssistant 1.3’s energy-logic model. They live in `packages/energy_metrics_1_3.yaml` and reference the canonical W-based flows from `packages/energy_core_1_3.yaml`.  
They provide planning-friendly abstractions, grid/battery limits, smoothed values, and stability signals used by peak control, export handling, EV logic, and dashboards.

All `ha1_power_*` sensors use **W** unless the name explicitly ends with `_kw`.

---

### 🔷 Meta Sensors (Derived kW, %)  

| Entity ID | Description | Unit | Based On |
|----------|-------------|------|----------|
<!-- TODO: sensor.ha1_ev_share_of_house_load_pct – restore EV share metric once rebuilt in energy_metrics_1_3.yaml -->
| **sensor.ha1_effective_peak_power_reference_kw** | Effective peak limit currently enforced by the system. Placeholder until Task 16 introduces helper-driven rule (incl. 22–06 0.5 factor). | kW | `input_number.ha1_peak_limit_kw` (future) |
| **sensor.ha1_peak_margin_kw** | Difference between current total consumption (kW) and the effective peak limit. Negative = under limit, positive = over limit. | kW | `ha1_power_consumption_total_kw`, `ha1_effective_peak_power_reference_kw` |

---

### 🔷 Battery Charging Capability Metrics (Huawei Limits)

These expose the real physical constraints of your Huawei inverter/LUNA system.

| Entity ID | Description | Unit | Based Based On |
|----------|-------------|------|----------------|
| **number.battery_grid_charge_maximum_power** | Maximum battery **grid-charging power** the inverter will accept. Clamped to **2.5 kW** as per hardware limit. | W | Huawei Solar integration |
| **number.battery_maximum_charging_power** | Maximum **overall** battery charge rate (grid + solar). Reflects the inverter’s full charging capability. | W | Huawei Solar integration |

Notes:  
- Grid-only charging is capped at ~2500 W.  
- Solar + grid together may exceed 2.5 kW depending on PV generation.  
- These metrics are essential for future EV/battery planning.

---

### 🔷 Smoothed Metrics (Rolling Averages, 1-minute)

These metrics use the `statistics` platform to stabilize decisions, avoid flapping, and create smooth dashboards.

| Entity ID | Description | Unit | Based On |
|----------|-------------|-------|----------|
| **sensor.ha1_power_house_total_avg_1m** | 1-minute rolling average of total household power (incl. EV). | W | `ha1_power_house_total` |
| **sensor.ha1_power_ev_charger_avg_1m** | 1-minute rolling average of EV charging power. | W | `ha1_power_ev_charger` |
| *(Existing from Codex earlier)* | | |
| `sensor.ha1_power_grid_net_avg_1m` | Net grid power average (import/export mixed). | W | `ha1_power_grid_total_net` |
| `sensor.ha1_flow_grid_import_avg_1m` | Import-only rolling average. | W | `ha1_flow_grid_import` |
| `sensor.ha1_flow_grid_export_avg_1m` | Export-only rolling average. | W | `ha1_flow_grid_export` |

---

### 🔷 Derived Binary Conditions (used by control behavior)

These are defined later in Task 15/16 but depend directly on the numeric metrics.

| Entity ID | Meaning | Conditions (concept) |
|----------|----------|----------------------|
| **binary_sensor.ha1_export_stable** | True when export power has been stable for a while. | `ha1_flow_grid_export_avg_1m > threshold` |
| **binary_sensor.ha1_near_peak_limit** | True when house load is close to the peak limit. | `0 ≤ ha1_peak_margin_kw ≤ threshold` and `ha1_power_house_total_avg_1m > min_load` |
| **binary_sensor.ha1_ev_is_major_load** | True when EV dominates house load. | `ev_share_pct > X%` and `ev_avg_power > Y W` |

Thresholds will be helper-driven in Task 16.

---

### 🔷 Summary

This extended sensor layer provides:

- **Human-friendly planning metrics (kW, %)**  
- **Accurate modeling of Huawei charge limits (grid-only and total)**  
- **Stable rolling averages** for real-time decisions  
- **State abstractions** for peak shaving, smart charging, export stability, and EV load prioritization.

Together they form the essential inputs for the HA 1.3 optimization logic that will be built in Tasks 16–20.

---

## 5. Verisure Alarm, Locks & Smart Plugs (Task 11)

**Goal:**  
Provide a consistent security layer that keeps the alarm state, perimeter sensors, front-door Lockguard, and Verisure-controlled loads aligned with occupancy automations and dashboards.

**Core entities & groups:**
- `alarm_control_panel.verisure_alarm` — canonical alarm mode that all arm/disarm flows use.
- `lock.entre` — Lockguard entity exposed via `script.verisure_lock` / `script.verisure_unlock`.
- `group.verisure_perimeter`, `group.verisure_environment`, `group.verisure_smart_plugs`, `group.verisure_locks`, and `group.verisure_system_status` — curated groups for dashboards, automations, and diagnostics.
- Verisure environment sensors (kitchen, upstairs, basement) supply temperature/humidity feeds for comfort logic and the AC function below.

**Key automations & scripts (from Task 11):**
- `automation.arm_leaving_home`, `automation.verisure_armed_home`, and `automation.alarm_notification` ensure the alarm follows presence and notifies on changes.
- `automation.unlock_coming_home` + `script.verisure_unlock` unlock the front door when trusted people arrive; `script.verisure_lock` / `script.verisure_arm_away` reset the system on departure.
- `automation.touch_display_on` / `_off` manage `switch.skarm` (the Verisure touch display) with guest-mode checks so the screen only powers when someone is home.
- Lighting helpers such as `automation.morning_light` reuse Verisure smart plugs (`switch.hallen`, `switch.kontor`, etc.) to keep manual scenes and alarm routines in sync.

**Behavior & guards:**
- Alarm state drives downstream routines (e.g., arming at night triggers lighting scenes, disarming resumes normal schedules).
- `input_boolean.guest_mode` and `input_boolean.away_mode` gate any automation that could otherwise power down devices or unlock doors at the wrong time.
- `group.verisure_system_status` surfaces connectivity (`binary_sensor.verisure_alarm_ethernet_status`) so dashboards can flag when the security layer is offline.

**Next steps / TODO:**
- Expose manual overrides (lock, arm/disarm, display power) on the 1.3 control dashboard with clear state feedback.
- Add history/logbook cards that correlate alarm transitions with presence, so unexpected arming/disarming can be audited quickly.

---

### Comfort Overrides & Exceptions – Phase 1 (HA 1.3)

**Entity:** `input_boolean.ha1_comfort_override_enabled`  
**Purpose:** Temporarily relax or bypass economic optimization rules when comfort takes priority.

#### What Comfort Override Does
When **ON**:
- EV charging is allowed even during “expensive” or “very_expensive” price levels.
- EV “pause on very expensive” rules are skipped.
- Peak-shaving EV-shedding automations do **not** activate.
- Battery and peak logic treat override as “comfort has priority”.
- Temporary exceptions are visually marked in UI and logged.

When **OFF**:
- Normal price-based logic applies.
- Peak-shaving automations operate normally.
- EV charging follows the economic strategy defined in Task 22.
- No optimization rules are bypassed.

#### Override Timer
- Override activation starts a timer: `timer.ha1_comfort_override`
- Duration set by: `input_number.ha1_comfort_override_duration_hours`
- When the timer ends:
  - `ha1_comfort_override_enabled` auto-turns **OFF**
  - System returns to normal optimization
  - A logbook entry is produced

#### Logging & Visibility
- Every ON/OFF/auto-expire event logs a message:
  - *“HA1: Comfort override enabled – price/peak limits may be relaxed.”*
  - *“HA1: Comfort override disabled – back to normal optimization.”*
- Status is visible in:
  - Debug dashboard (test card)
  - Override timer state
  - Helper toggle state

#### Safety
Comfort override relaxes **economic** limits only.  
It does **not** disable:
- Master automation guard
- Physical or electrical safety checks
- Charger state requirements
- SOC constraints
- Critical peak hard limits (system-designed failsafes)

#### Testing Tools (Internal)
For development and validation:
- `script.ha1_test_ev_price_override_logic`
- `input_boolean.ha1_test_ev_price_override_result`
- Effective price override: `input_select.ha1_test_price_level_effective`
- Testing mode: `input_boolean.ha1_testing_mode_enabled`

These tools allow isolated testing of price-level vs comfort override logic without depending on real charger/car states.

---

## 7. Export / Import Strategy

**Goal:**  
Define rules for when export is allowed and when energy should be used locally or stored in the battery.

**Considerations:**
- Never export solar while battery needs charging (unless manually overridden).
- Use hysteresis or averaging to avoid rapid toggling of export states.
- Respect contractual limitations if any.

---

## 8. Logging, Diagnostics & Safety

**Goal:**  
Provide enough data to understand why the system behaved a certain way.

**Planned elements:**
- Key sensors grouped in diagnostic views.
- Logbook-friendly messages for major actions (start/stop charging, change mode, hit new peak, etc.).
- Simple debug toggles (extra logging on/off).

---

Further sections will be filled in as functions are implemented and tuned in 1.3.

## 9. Climate / AC

**Goal:**  
Use surplus solar generation to drive cooling while preventing unnecessary grid imports.

### AirCondition – Solar-driven start/stop (Huawei)

- **Purpose:**  
  Automatically start and stop the upstairs air conditioning based on available solar power from the Huawei inverter, so AC usage follows surplus production instead of drawing unnecessary power from the grid.

- **Inputs / Entities:**
  - `sensor.ha1_huawei_solar_power` – Canonical 1.3 solar power from Huawei (kW, AC side).
  - `climate.air_conditioning` – Upstairs AC unit controlled through `climate.set_temperature` / `climate.set_hvac_mode`.
  - `input_boolean.away_mode` – Guard to block cooling when the home is marked as away.
  - `sensor.overvaningen_temperature` – Upstairs temperature source for comfort thresholds.

- **Trigger & thresholds:**
  - **Start automation:** Triggers when `sensor.ha1_huawei_solar_power` rises **above 2.5 kW** and the home is not in away mode while `sensor.overvaningen_temperature` is above 26 °C.
  - **Stop automation:** Triggers when `sensor.ha1_huawei_solar_power` falls **below 2.5 kW** and the upstairs temperature has dropped under 25 °C.

- **Behavior:**
  - When solar power is high enough, the AC is allowed to run using surplus PV energy.
  - When solar production drops below the threshold, the AC is turned off to avoid unnecessary grid import.
  - The logic uses the normalized HA1 sensor (kW) so it stays consistent with other 1.3 energy flows and visualizations.

- **Notes / Conventions:**
- `sensor.ha1_huawei_solar_power` is in **kW** and is derived from the Huawei inverter’s active power.
- This function depends on the Huawei Solar integration being online and the canonical 1.3 package `huawei_solar_1_3.yaml` being active.
- Any further optimization (e.g., combining Nordpool price windows or peak shaving constraints) should be documented in a separate subsection.

---

## 10. Weather & Environment (Task 12)

**Goal:**  
Expose a normalized weather interface (SMHI primary, Met.no backup) and Forecast.Solar PV predictions so dashboards, comfort logic, and future planners consume the same data set.

**Primary sensors:**
- `weather.smhi_home` — canonical weather entity for condition + icon; mirrored by `sensor.ha1_weather_condition`.
- `weather.home` / `weather.home_hourly` — kept online for comparison and fallback only.
- Template sensors sourced from SMHI (`sensor.ha1_outdoor_temperature`, `sensor.ha1_outdoor_humidity`, `sensor.ha1_outdoor_feels_like`, `sensor.ha1_wind_speed`, `sensor.ha1_wind_bearing`) feed dashboards, climate guards, and comfort diagnostics.
- Verisure indoor sensors (`group.verisure_environment`) bridge the gap between outdoor references and actual indoor climate measurements.

**Forecast.Solar references:**
- `sensor.energy_production_today` / `_tomorrow`, `sensor.power_production_now`, `sensor.power_highest_peak_time_today` / `_tomorrow`, and hourly energy estimates provide the PV outlook that future (Task 14+) scheduling logic will need.
- These sensors are captured in documentation and verified in HA but deliberately unused until peak shaving, battery, and EV planners can consume them consistently.

**Usage & next steps:**
- Dashboards should pull outdoor temperature/humidity/wind from the HA1 template sensors, not directly from the weather integration, to keep units/sign conventions uniform.
- Climate/comfort automations (including the AC section above) will start referencing `sensor.ha1_outdoor_temperature` once the guardrails are defined.
- When Task 13+ introduces forecasting logic, reuse these Forecast.Solar entities instead of recreating ad-hoc forecasts.

## 🔍 Diagnostics & Status (HA 1.3)

The Diagnostics layer provides a unified technical overview of the HomeAssistant 1.3 energy system.
It is designed for **debugging**, **system validation**, and **automation insight**, not as a GUI layer.

Diagnostics are divided into functional groups:

### 🏭 `group.ha1_diag_grid` — Grid & Import/Export
Key sensors related to grid interaction:
- Real-time import/export power
- Net grid power (kW)
- Interval power (real & cost-adjusted)
- Daily/hourly/monthly import energy
- Monthly peak values

Used to verify tariff behaviour, interval tracking, and peak shaving.

### 🔋 `group.ha1_diag_solar_battery` — Solar & Battery
Summarizes PV production, battery power flow, and internal energy routing:
- Solar input/output power
- Battery SOC and charge/discharge power
- Canonical HA1 flows (solar→house, solar→battery, battery→house, house→grid, EV from grid)

Used to confirm correct energy distribution between PV, battery, house, and EV.

### 🚗 `group.ha1_diag_ev` — EV & Charger
Combines Easee + ID.4 entities:
- Instant charging power
- Charger state & enable switch
- Session and lifetime energy
- Vehicle charging time left, SOC, and charging state

Used to verify EV charging behaviour and automations.

### 💰 `group.ha1_diag_prices` — Nordpool Prices
Includes Nordpool raw price and HA1-level derived price signals:
- Current price
- Today’s average/min/max
- Status sensors (cheap/normal/expensive, relative%)

Used to inspect price-driven automation behaviour.

### 📈 `group.ha1_diag_peaks` — Peak Tracking
Contains all peak and interval-based tariff metrics:
- Current interval length, energy, power
- Top-3 peaks
- Monthly peak values (real & cost-adjusted)
- Monthly top-3 averages

Used to validate peak-shaving logic and tariff calculations.

### 🛠 `group.ha1_diag_helpers` — Modes, Toggles & Overrides
Displays the current system control state:
- Peak interval mode
- Peak limit & warning margin
- Battery automation toggle + limits
- EV automation toggle + SOC & current limits
- Comfort override + force-charge controls

Used to inspect current automation inputs/settings.

## ⭐ `group.ha1_system_status` — Headline Status View

A compact group used for GUI and at-a-glance monitoring.
Includes:
- Net grid power (kW)
- Battery SOC
- EV charging power
- Current price
- Interval power
- Peak shaving enabled
- Price level (cheap/normal/expensive)
- Peak near limit (boolean)

Designed as the **top-level card** in the upcoming HA 1.3 GUI work.

## 🧠 Status Sensors (HA1 Summary Signals)

The diagnostics layer defines several “meta” state sensors:

**`sensor.ha1_status_price_level`**  
Classifies current price vs average price.  
States: **cheap**, **normal**, **expensive**

**`sensor.ha1_status_price_relative`**  
Percentage difference between current and today’s average price.

**`sensor.ha1_status_peak_near_limit`**  
True when interval power is within the configured peak-warning margin.

**`sensor.ha1_status_ev_state`**  
Summarized EV state: **charging**, **plugged in**, **idle**

**`sensor.ha1_status_battery_state`**  
Summarized battery behaviour: **charging**, **discharging**, **idle**

## 📝 Logging Helper Scripts (HA1 Unified Logbook Events)

The HA 1.3 logging package provides reusable scripts for writing structured messages to the Logbook:
- `script.ha1_log` — Generic events
- `script.ha1_log_peak` — Peak-related events
- `script.ha1_log_price` — Price transitions
- `script.ha1_log_ev` — EV/charger events
- `script.ha1_log_battery` — Battery events
- `script.ha1_log_override` — Overrides & system mode changes

Used by automations to ensure clean, consistent Logbook entries.

## ✔ Purpose of the Diagnostics Layer
- Make the system easy to debug
- Give clear insight into automation decisions
- Ensure HA1.3 behaviour is predictable and inspectable
- Provide the backend structure for GUI views (Tasks 19–22)
- Support future AI/optimizer logic

## Using EV Charging Automations – Phase 1

### Overview
Phase 1 automates safe EV charging: it prefers cheap hours, obeys your peak-limit slider, and triggers a time-critical fallback if charging is running late. Manual overrides remain available, and **automatic charging currently works only when the EV mode is set to `cheap_only`.**

### Required setup
Before automations can run, confirm:
- EV is plugged in and the Easee charger reports `awaiting_start` or `ready_to_charge`.
- `input_boolean.ha1_automations_master_enable` = ON.
- `input_boolean.ha1_ev_automation_enabled` = ON.
- `input_select.ha1_ev_charging_mode` = `cheap_only`.
- `input_number.ha1_peak_limit_kw` is set to match your tariff.
- EV price threshold sliders are adjusted on the maintenance card:
  - `input_number.ha1_ev_price_cheap_max`
  - `input_number.ha1_ev_price_normal_max`
  - `input_number.ha1_ev_price_expensive_max`

### How to use the system
1. Plug in the car as usual.
2. Leave the EV mode on `cheap_only` (or switch to it).
3. Ensure the master and EV automation toggles are ON.
4. The system will start charging automatically when price and peak conditions are safe. It also pauses charging if the peak limit is breached.
5. To charge immediately regardless of price, either enable `input_boolean.ha1_force_ev_charge_now` or switch to `manual` mode and start charging from the Easee app/dashboard.

### EV charging modes
- `off` – No automatic starts; use manual controls only.
- `cheap_only` – Phase‑1 automation logic (cheap-preferring with fallback).
- `balanced` – Placeholder for Phase 2 (currently behaves like manual).
- `aggressive` – Placeholder for Phase 2 (currently behaves like manual).
- `manual` – User controls charging fully; automation stays idle.

### When sensors are unavailable
- If `sensor.id4pro_charging_time_left` is unavailable, cheap-only starts still occur, but the time-critical fallback is disabled until the sensor recovers.
- If `sensor.ha1_ev_cheap_hours_remaining_24h` is unavailable, the adaptive fallback is disabled so the system never guesses when it is unsure.

### Tips for best results
- Tune the EV price thresholds to reflect your comfort level and current market conditions.
- Align the peak-limit slider with your actual tariff limit to avoid unnecessary stops.
- Set a realistic “cheap” price—too low may delay charging until very late.
- Let the vehicle “wake up” periodically so SOC and time-left data stay fresh.
- Use “Force charge now” sparingly; turn it off when you want automations to resume control.

### Where to view automation activity
All events appear in **Activities (Logbook)**. Typical entries include:
- “EV charging started (cheap price)”
- “EV charging paused due to peak limit”
- “EV charging started by adaptive fallback”

This section completes the user-facing manual for EV Charging Automations – Phase 1.

### EV Charging Modes – cheap_only, balanced, aggressive (HA 1.3 Task 22)

#### New EV Price-Level Thresholds (SEK/kWh)
EV price classification now uses numeric sliders (replacing the old text-based mapping):
- `input_number.ha1_ev_price_cheap_max`
- `input_number.ha1_ev_price_normal_max`
- `input_number.ha1_ev_price_expensive_max`

Classification:
- `cheap` = price ≤ cheap_max
- `normal` = price > cheap_max and ≤ normal_max
- `expensive` = price > normal_max and ≤ expensive_max
- `very_expensive` = price > expensive_max

These thresholds drive the EV price sensor (`sensor.ha1_ev_price_level`) that controls EV start/stop logic and mode behaviour (`cheap_only`, `balanced`, `aggressive`).

#### Mode: cheap_only
- Charges in `cheap`; also in `normal` if time_left ≤ 3h.
- Never charges in `expensive` or `very_expensive`.
- Peak safety: start only if net grid avg ≤ 80% of peak limit.
- Automations: `ha1_ev_start_cheap_only`, `ha1_ev_start_time_critical_adaptive`.

#### Mode: balanced
- Charges in `cheap` and `normal`.
- Charges in `expensive` only if time_left ≤ 1h.
- Never charges in `very_expensive` unless time_left < 1h.
- Peak safety: start only if net grid avg ≤ 90% of peak limit.
- Applies `input_number.ha1_ev_limit_current_a` on start.
- Automation: `ha1_ev_start_balanced`.

#### Mode: aggressive
- Charges in `cheap`, `normal`, `expensive`.
- Charges in `very_expensive` only if time_left ≤ 1h.
- Peak safety: start only if net grid avg ≤ 95% of peak limit.
- Applies `input_number.ha1_ev_limit_current_a` on start.
- Automation: `ha1_ev_start_aggressive`.

#### EV Charging Pause Conditions
- Peak limit pause: if charging and net grid avg ≥ peak limit → pause. Automation: `ha1_ev_pause_on_peak_limit`.
- Very expensive pause:
  - Balanced: pause if `very_expensive` and time_left > 3h.
  - Aggressive: pause if `very_expensive` and time_left > 1h.
  - Automation: `ha1_ev_pause_on_very_expensive_price`.

#### Entity Reference (new/updated)
- Helpers: `input_number.ha1_ev_price_cheap_max`, `input_number.ha1_ev_price_normal_max`, `input_number.ha1_ev_price_expensive_max`, `input_number.ha1_ev_limit_current_a`.
- Sensor: `sensor.ha1_ev_price_level`.
- Automations: `ha1_ev_start_cheap_only`, `ha1_ev_start_time_critical_adaptive`, `ha1_ev_pause_on_peak_limit`, `ha1_ev_start_balanced`, `ha1_ev_start_aggressive`, `ha1_ev_pause_on_very_expensive_price`.
