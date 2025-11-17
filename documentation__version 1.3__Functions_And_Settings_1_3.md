Last updated: 2025-11-17 15:53 (CET) — Authorized by ChatGPT

# ⚙️ Functions & Settings – HomeAssistant 1.3

**Purpose:**  
Describe how the main functions of HomeAssistant 1.3 behave, which settings control them, and which entities they depend on. This is the “how it works” document for future you.

---

## 1. Peak Shaving

**Goal:**  
Limit monthly peak power while respecting comfort and necessary charging.

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

- **Global / Peak:** `input_boolean.ha1_automation_master_enabled`, `input_boolean.ha1_peak_shaving_enabled`, `input_number.ha1_peak_limit_kw`, `input_number.ha1_peak_warning_kw`.
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

## 6. Comfort Overrides

**Goal:**  
Allow manual or automatic overrides that prioritize comfort over optimization, while keeping this fully visible in the UI.

**Examples:**
- “Heat now even if price is high.”
- “Charge EV now regardless of peaks.”
- “Disable export limitation temporarily.”

Each override must:
- Be clearly visible on the main dashboard.
- Have a clear reset path.
- Be logged or at least easy to see in history.

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
