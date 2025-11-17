Last updated: 2025-11-17 14:41 (CET) — Authorized by ChatGPT

# 🔌 Integrations & Sensors – HomeAssistant 1.3

**Purpose:**  
Document all integrations and their important entities (sensors, switches, numbers, etc.) used in HomeAssistant 1.3, with focus on energy optimization, safety, and comfort.

This file is the **technical reference**; the rulebook remains the high-level description.

---

## 📦 1. Core Energy Integrations

### 1.1 Huawei Solar & LUNA2000 (PV + Battery)

**Purpose:** Core PV + battery integration. Provides real-time power, SOC and energy counters for solar production, battery charging/discharging and Huawei power meter readings. All 1.3 logic uses the normalized `HA1` sensors.

**Key base entities (raw from integration)**

- `sensor.inverter_active_power` – Inverter AC output power (W).
- `sensor.inverter_energy_yield_today` – Solar energy produced today (kWh).
- `sensor.inverter_total_energy_yield` – Total solar energy produced (kWh).
- `sensor.battery_charge_discharge_power` – Battery charge/discharge power (W).
- `sensor.storage_state_of_capacity` – Aggregated battery state of capacity (SOC, %).
- `sensor.energy_charged_today` / `sensor.energy_discharged_today` – Battery energy charged / discharged today (kWh).
- `sensor.total_charged_energy` / `sensor.total_discharged_energy` – Total battery charged / discharged energy (kWh).
- `sensor.power_meter_active_power` – Huawei power meter active power at grid connection (W).
- `sensor.storage_running_status` – Overall storage system status.
- `sensor.battery_working_mode` – Reported battery mode/state.
- `select.storage_working_mode_settings` – Selects storage working mode.
- `switch.storage_charge_from_grid_function` – Enables/disables charging battery from grid.

**Canonical 1.3 sensors (used by dashboards and automations)**

- `sensor.ha1_huawei_solar_power` – Solar/inverter power (kW, AC side).
- `sensor.ha1_huawei_battery_power` – Battery power (kW). Positive = charging, negative = discharging.
- `binary_sensor.ha1_huawei_battery_charging` – `on` when battery is charging.
- `binary_sensor.ha1_huawei_battery_discharging` – `on` when battery is discharging.
- `sensor.ha1_huawei_battery_soc` – Main LUNA2000 battery SOC (%).
- `sensor.ha1_huawei_solar_energy_today` / `sensor.ha1_huawei_solar_energy_total` – Solar energy (kWh).
- `sensor.ha1_huawei_battery_energy_charged_today` / `sensor.ha1_huawei_battery_energy_discharged_today` – Battery energy in/out today (kWh).
- `sensor.ha1_huawei_battery_energy_charged_total` / `sensor.ha1_huawei_battery_energy_discharged_total` – Battery energy in/out total (kWh).
- `sensor.ha1_huawei_grid_power` – Huawei grid power from power meter (kW). Positive = import, negative = export (aligned with `sensor.grid_import_export_power`).

**Caveats / conventions**

- All `HA1` power sensors use **kW**.
- All `HA1` energy sensors use **kWh** and `total_increasing` where applicable.
- Battery power sign convention: **positive = charging, negative = discharging**.
- Grid power sign convention: **positive = importing from grid, negative = exporting to grid**.
- Pack-level sensors (`sensor.pack_1_*`, `sensor.pack_2_*`, `sensor.pack_3_*`) are available for diagnostics but not used in primary logic.

---

### ⚡ Grid Meter / Import–Export (Integration #2)

**Integration:**
- Easee – Device: `QP57QZ4Q` (P1 grid meter / DSO meter)
- Huawei Solar – Device: `Power meter` (diagnostic / inverter-side meter)

#### Canonical 1.3 Grid Sensors

**Primary net power (for all optimization and flows)**

- `sensor.grid_import_export_power`
  - Source: template (QP57QZ4Q import/export)
  - Unit: kW
  - Device class: `power` (measurement)
  - **Sign convention:**
    - Positive → **Import from grid**
    - Negative → **Export to grid**

- `sensor.grid_active_power`
  - Source: template (absolute value of `sensor.grid_import_export_power`)
  - Unit: kW
  - Device class: `power` (measurement)
  - Meaning: Magnitude of grid exchange, independent of direction.

**Primary energy totals (billing reference)**

- `sensor.qp57qz4q_import_energy`
  - Canonical: Total grid import (kWh)
  - Device class: `energy`

- `sensor.qp57qz4q_export_energy`
  - Canonical: Total grid export (kWh)
  - Device class: `energy`

**Utility meters (HA1 billing windows)**

- `sensor.ha1_grid_import_energy_daily`
  - Source: `sensor.qp57qz4q_import_energy` via `utility_meter`
  - Cycle: resets daily
  - Use: tracks daily import for dashboards, reports, and sanity checks versus Nordpool billing.

- `sensor.ha1_grid_import_energy_weekly`
  - Source: `sensor.qp57qz4q_import_energy`
  - Cycle: resets weekly (Utility Meter default week)
  - Use: reference for weekly import budgets and future Task 16 alerts.

- `sensor.ha1_grid_export_energy_daily`
  - Source: `sensor.qp57qz4q_export_energy`
  - Cycle: resets daily
  - Use: monitors daily export totals when comparing PV/battery strategies.

- `sensor.ha1_grid_export_energy_weekly`
  - Source: `sensor.qp57qz4q_export_energy`
  - Cycle: resets weekly (Utility Meter default week)
  - Use: weekly export accounting for dashboards/notifications.

**Diagnostic / secondary (Huawei Solar meter)**

- `sensor.power_meter_active_power` (W)
- `sensor.power_meter_phase_a_active_power` / `_b_` / `_c_` (W)
- `sensor.power_meter_consumption` (kWh import)
- `sensor.power_meter_exported` (kWh export)

These are used for detailed PV/battery flow views and cross-checking the P1 grid meter, but **all peak shaving, Nordpool/ha1 planners, EV and export logic** must reference the *canonical* grid sensors above.

---

## Easee EV Charger & ID.4 (Task 10)

**Purpose:** Provide a clean EV charging layer for 1.3 that integrates Easee charger data and ID.4 vehicle data into a small set of canonical sensors for automation and visualization.

### Raw integration entities (from UI integrations)

**Easee charger (device id: ehxdyl83)**

- `sensor.ehxdyl83_power` – Instantaneous charger power (W).
- `sensor.ehxdyl83_session_energy` – Energy used in the current charging session (kWh).
- `sensor.ehxdyl83_lifetime_energy` – Lifetime energy counter (kWh).
- `sensor.ehxdyl83_status` – Text status of the charger (idle/charging/finished/error/etc.).
- `sensor.ehxdyl83_current` – Actual charging current (A).
- `sensor.ehxdyl83_max_charger_limit` – Current limit / max allowed charging current (A).
- Other relevant:
  - `sensor.ehxdyl83_voltage`
  - `binary_sensor.ehxdyl83_online`
  - `binary_sensor.ehxdyl83_cable_lock`
  - `sensor.ehxdyl83_reason_for_no_current`
  - `switch.ehxdyl83_charger_enabled`
  - `switch.ehxdyl83_smart_charging`
  - `light.ehxdyl83_led_strip`
  - etc.

**ID.4 (VW WeConnect)**

- `sensor.id4pro_charging_time_left` – Remaining charging time reported by the car (key planning input).
- `sensor.id4pro_battery_level` – Battery state of charge (%).
- `sensor.id4pro_electric_range` – Estimated electric driving range (km).
- Other useful:
  - `sensor.id4pro_charging_power`
  - `sensor.id4pro_charging_rate`
  - `sensor.id4pro_charger_max_ac_setting`
  - `binary_sensor.id4pro_charging_cable_connected`
  - `binary_sensor.id4pro_charging_cable_locked`
  - `switch.id4pro_charging`
  - `device_tracker.id4pro_position`
  - etc.

### Canonical 1.3 EV layer (created in packages/ev_charging_1_3.yaml)

These sensors are the **standard interface** for all EV-related logic in HomeAssistant 1.3:

- `sensor.ev_charger_power` – EV charging power in kW (derived from `sensor.ehxdyl83_power`).
- `sensor.ev_charger_power_w` – Raw charger power in W (direct passthrough).
- `sensor.ev_session_energy` – Session energy in kWh (alias of `sensor.ehxdyl83_session_energy`).
- `sensor.ev_total_energy` – Lifetime EV charging energy in kWh (alias of `sensor.ehxdyl83_lifetime_energy`).
- `sensor.ev_charger_current` – Actual charging current in A (alias of `sensor.ehxdyl83_current`).
- `sensor.ev_charger_current_limit` – Current limit in A (alias of `sensor.ehxdyl83_max_charger_limit`).
- `sensor.ev_charging_state_raw` – Text status from Easee (mirror of `sensor.ehxdyl83_status`).
- `binary_sensor.ev_is_charging` – Boolean “EV is charging” state based on charger power.
- `sensor.ev_charging_time_left` – Planning input, passthrough of `sensor.id4pro_charging_time_left`.
- `sensor.ev_battery_soc` – EV battery state of charge % (alias of `sensor.id4pro_battery_level`).
- `sensor.ev_estimated_range` – EV estimated driving range in km (alias of `sensor.id4pro_electric_range`).

**Important:** `sensor.ev_charging_time_left` is explicitly treated as a **planning input** for EV charging automations (cheapest hours, peak shaving, and grid/battery coordination).

---

## 📊 HA1 Template Sensor Layer (Task 15)

**Purpose:** Provide the canonical measurement surface for all energy logic. Raw vendor outputs are normalized once (Task 14) and Task 15 adds kW rollups, peak helpers, and rolling averages so dashboards/autos share identical math.

**Location:**  
- Core flows live in `packages/energy_core_1_3.yaml` (raw **W** sensors).  
- Extended metrics + statistics live in `packages/energy_metrics_1_3.yaml`.  
- Grid utility meters reside in `packages/ev_charging_1_3.yaml`.

### 2.1 Core HA1 Power/Flow Sensors (`energy_core_1_3.yaml`)

| Entity | Description | Notes |
|--------|-------------|-------|
| `sensor.ha1_power_house_total` | Total household load incl. EV (W). | Backbone for `*_total_kw` metrics; legacy dashboards bind via `sensor.home_load`. |
| `sensor.ha1_power_house_core` | House load excluding EV charger (W). | Used for “core consumption” dashboards. |
| `sensor.ha1_power_ev_charger` | EV charging power (W). | Derived from Easee data; signless consumption. |
| `sensor.ha1_power_grid_total_net` | Net grid power (W). Positive import / negative export. | Every automation that references the grid must read this sensor. |
| `sensor.ha1_flow_grid_import` / `sensor.ha1_flow_grid_export` | Import/export-only views (W). | Simplifies billing/exceed checks and supports smoothed averages. |
| `sensor.ha1_flow_battery_discharge`, `sensor.ha1_flow_solar_to_house`, etc. | Canonical PV/battery/house interface sensors. | Provide clarity for dashboards and balance checks. |

### 2.2 Extended Metrics & Peak Helpers (`energy_metrics_1_3.yaml`)

| Entity | Purpose | Based on |
|--------|---------|----------|
| `sensor.ha1_power_consumption_total_kw` / `_core_kw` | Human-scale kW totals for dashboards/alerts. | `sensor.ha1_power_house_total/core`. |
| `sensor.ha1_power_net_load_kw` / `_abs_kw` | Signed/absolute net grid load in kW. | `sensor.ha1_power_grid_total_net`. |
| `sensor.ha1_effective_peak_power_reference_kw` | Active peak limit reference (currently helper passthrough). | `input_number.ha1_peak_limit_kw`. |
| `sensor.ha1_peak_margin_kw` | Distance between current load and peak limit. | `sensor.ha1_power_consumption_total_kw`. |
| `sensor.ha1_ev_share_of_house_load_pct` | Shows when EV dominates consumption. | `sensor.ha1_power_house_total`, `sensor.ha1_power_ev_charger`. |
| `sensor.ha1_batt_grid_charge_limit_kw` / `_total_charge_limit_kw` | Mirrors Huawei charge limits in kW, clamped. | `number.battery_grid_charge_maximum_power`, `number.battery_maximum_charging_power`. |
| Rolling averages (`sensor.ha1_power_grid_net_avg_1m/5m`, `sensor.ha1_power_house_total_avg_1m`, `sensor.ha1_flow_grid_import_avg_1m/5m`, etc.) | Smooth noisy datasets for automation guards and dashboards. | `statistics` platform inside the same package. |

### 2.3 Utility Meters (Grid)

| Entity | Interval | Notes |
|--------|----------|-------|
| `sensor.ha1_grid_import_energy_daily` / `_weekly` | Daily / weekly import totals. | Source: `sensor.qp57qz4q_import_energy`. |
| `sensor.ha1_grid_export_energy_daily` / `_weekly` | Daily / weekly export totals. | Source: `sensor.qp57qz4q_export_energy`. |

These counters supersede ad-hoc dashboards and will back Task 16 peak-cost monitoring.

---

### 1.4 Nordpool Electricity Prices

- **Role:** Hourly electricity price feed from the official Nordpool integration.
- **Active entity (UI-configured):**
  - `sensor.nordpool_kwh_se3_sek_3_10_025` — current SE3 price in SEK.
- **Removed in 1.3 cleanup:** all YAML-based Nordpool sensors, planners, cheapest-hours helpers, and automations (`sensor.nordpool_kwh_se3_eur_2_095_025`, planner outputs, pool-pump/battery price automations, etc.). Any future price logic must reference the single UI-managed sensor above.
- **Example usage snippets (plug into the UI or YAML automations if needed):**
  - **Automation:** trigger when price drops below 1.20 SEK/kWh.

    ```yaml
    trigger:
      - platform: numeric_state
        entity_id: sensor.nordpool_kwh_se3_sek_3_10_025
        attribute: current_price
        below: 1.20
    action:
      - service: huawei_solar.forcible_charge_soc
        data:
          target_soc: 100
    ```

  - **Dashboard:** show the same sensor in an Entities card with price trend attribute.

    ```yaml
    type: entities
    title: SE3 Price
    entities:
      - entity: sensor.nordpool_kwh_se3_sek_3_10_025
        name: Current price
        secondary_info: last-changed
    ```

---

## Verisure – Alarm, Security & Smart Plugs

**Purpose:**  
Provide security state (alarm modes), perimeter and lock status, selected environmental data, and controllable loads (smart plugs) from the Verisure system.

---

### Alarm Control Panel

| Entity ID                            | Description                               | Notes                                                                 |
|--------------------------------------|-------------------------------------------|-----------------------------------------------------------------------|
| `alarm_control_panel.verisure_alarm` | Main Verisure alarm control panel         | States: `disarmed`, `armed_home`, `armed_away`, `triggered`, etc.; used by core scripts and automations (arm/disarm, notifications). |

---

### System Status

| Entity ID                                      | Description                                | Notes                                           |
|------------------------------------------------|--------------------------------------------|-------------------------------------------------|
| `binary_sensor.verisure_alarm_ethernet_status` | Verisure alarm ethernet/cloud connectivity | Used in `group.verisure_system_status` for health/status monitoring. |

---

### Perimeter Sensors (Doors/Windows)

| Entity ID                         | Description                      | Notes                                          |
|-----------------------------------|----------------------------------|------------------------------------------------|
| `binary_sensor.entredorr_opening` | Front door (opening sensor)      | Member of `group.verisure_perimeter`.         |
| `binary_sensor.kallardorr_opening` | Basement door (opening sensor)   | Member of `group.verisure_perimeter`.         |
| `binary_sensor.altandorr_opening` | Patio door/window contact        | Member of `group.verisure_perimeter`.         |
| `binary_sensor.balkongen_opening` | Balcony door/window contact      | Member of `group.verisure_perimeter`.         |

---

### Motion Detectors

| Entity ID | Description | Notes |
|-----------|-------------|-------|
| _none_    | No Verisure motion detectors configured in 1.3 | `group.verisure_motion` remains intentionally empty. |

---

### Environmental Sensors

| Entity ID                        | Description                               | Notes                                                                 |
|----------------------------------|-------------------------------------------|-----------------------------------------------------------------------|
| `sensor.koket_temperature`       | Kitchen temperature (Verisure sensor)     | Member of `group.verisure_environment`.                               |
| `sensor.overvaningen_temperature` | Upstairs temperature                      | Used by `automation.aircondition_start` and `automation.aircondition_stop`. |
| `sensor.kallartrapp_temperature` | Basement stair temperature                | Member of `group.verisure_environment`.                               |
| `sensor.overvaningen_temperature_2` | Upstairs temperature (secondary channel) | Spare / future use; included in `group.verisure_environment`.         |
| `sensor.kallartrapp_temperature_2` | Basement stair temperature (secondary)    | Spare / future use; included in `group.verisure_environment`.         |
| `sensor.overvaningen_humidity`   | Upstairs humidity                         | Member of `group.verisure_environment`.                               |
| `sensor.kallartrapp_humidity`    | Basement stair humidity                   | Member of `group.verisure_environment`.                               |
| `sensor.overvaningen_humidity_2` | Upstairs humidity (secondary channel)     | Spare / future use; included in `group.verisure_environment`.         |
| `sensor.kallartrapp_humidity_2`  | Basement stair humidity (secondary)       | Spare / future use; included in `group.verisure_environment`.         |

---

### Smart Plugs / Loads

| Entity ID         | Description                         | Notes                                                              |
|-------------------|-------------------------------------|--------------------------------------------------------------------|
| `switch.sovrum`   | Bedroom plug                        | Part of general lighting/window groups (scenes) in `groups.yaml`.  |
| `switch.hallen`   | Hallway plug                        | Used in lighting groups.                                           |
| `switch.allroom_corner` | Allroom corner plug            | Used in lighting/window scene groupings.                           |
| `switch.trappfonster`   | Stair window plug              | Used in lighting/window scene groupings.                           |
| `switch.kontor`   | Office plug                         | Member of `group.verisure_smart_plugs`; used by `automation.morning_light`. |
| `switch.skarm`    | Verisure display power (touch panel) | Member of `group.verisure_smart_plugs`; controlled by `automation.touch_display_on` / `automation.touch_display_off` and `script.nightlight`. |

---

### Locks

| Entity ID    | Description                       | Notes                                                                                           |
|--------------|-----------------------------------|-------------------------------------------------------------------------------------------------|
| `lock.entre` | Front door Lockguard (Verisure)  | Member of `group.verisure_locks`; controlled by `script.verisure_unlock`, `script.verisure_lock`, and `automation.unlock_coming_home`. |

---

### Verisure Scripts / Helpers

| ID / Entity ID               | Type         | Description                                       | Notes                                                           |
|------------------------------|--------------|---------------------------------------------------|-----------------------------------------------------------------|
| `automation.verisure_armed_home` | Automation | Reacts to alarm being armed_home                  | Triggers night routines (e.g. `automation.night_light`).        |
| `automation.unlock_coming_home` | Automation | Unlocks front door on arriving home               | Calls `script.verisure_unlock` when zone/home conditions match. |
| `automation.arm_leaving_home` | Automation   | Arms alarm when leaving home                      | Calls `script.verisure_arm_away` when both people are away.     |
| `automation.touch_display_on` | Automation   | Powers on Verisure display when someone is home   | Also runs daily at 06:00.                                      |
| `automation.touch_display_off` | Automation  | Powers off Verisure display when all are away     | Checks guest mode before turning off.                           |
| `automation.alarm_notification` | Automation | Sends notification when alarm is triggered        | Listens to `alarm_control_panel.verisure_alarm` state changes.  |
| `automation.morning_light`   | Automation   | Morning light/scene logic                         | Also toggles `switch.kontor` as part of the scene.             |
| `automation.aircondition_start` | Automation | Starts air conditioning above temperature limit   | Uses `sensor.overvaningen_temperature` plus price/solar/away logic. |
| `automation.aircondition_stop` | Automation  | Stops air conditioning once cooled sufficiently   | Uses `sensor.overvaningen_temperature`.                         |
| `script.1637005175553`       | Script       | Arm alarm – home mode                             | Calls `alarm_control_panel.alarm_arm_home` on Verisure alarm.  |
| `script.verisure_arm_away`   | Script       | Arm alarm – away mode                             | Calls `alarm_control_panel.alarm_arm_away`.                     |
| `script.verisure_disarm`     | Script       | Disarm alarm                                      | Calls `alarm_control_panel.alarm_disarm`.                       |
| `script.verisure_unlock`     | Script       | Unlock front door                                 | Sends `lock.unlock` to `lock.entre`.                            |
| `script.verisure_lock`       | Script       | Lock front door                                   | Sends `lock.lock` to `lock.entre`.                              |

---

## 🌡️ 2. Weather & Environment

### Provider Overview

- **Primary weather provider:** SMHI (`weather.smhi_home`)
- **Secondary / backup provider:** Met.no (`weather.home`, `weather.home_hourly`)
- **PV forecast provider:** Forecast.Solar (multiple `sensor.energy_*` / `sensor.power_*` entities)
- **Indoor environment:** Verisure environment sensors (see Verisure section)

### Canonical Weather & Environment Entities (HA 1.3)

These sensors form the standard weather interface for all 1.3 logic and dashboards.

| Purpose                  | Entity ID                          | Source          | Notes                                                |
|--------------------------|------------------------------------|-----------------|------------------------------------------------------|
| Main weather entity      | `weather.smhi_home`               | SMHI            | Used by default weather card and condition display  |
| Backup weather entity    | `weather.home`                    | Met.no          | Kept as backup/compare; not used in logic (yet)     |
| Outdoor temperature      | `sensor.ha1_outdoor_temperature`  | Template (SMHI) | From `weather.smhi_home.temperature`                |
| Outdoor humidity         | `sensor.ha1_outdoor_humidity`     | Template (SMHI) | From `weather.smhi_home.humidity`                   |
| Outdoor feels-like temp  | `sensor.ha1_outdoor_feels_like`   | Template (SMHI) | Prefers `apparent_temperature`, falls back to temp  |
| Wind speed               | `sensor.ha1_wind_speed`           | Template (SMHI) | From `weather.smhi_home.wind_speed`                 |
| Wind direction (bearing) | `sensor.ha1_wind_bearing`         | Template (SMHI) | From `weather.smhi_home.wind_bearing`               |
| Weather condition        | `sensor.ha1_weather_condition`    | Template (SMHI) | Mirrors state of `weather.smhi_home`                |

### Forecast.Solar – PV Forecast Entities

These entities are available for future solar/battery/EV planning.  
They are **not yet used** in 1.3 automations or dashboards (Task 12).

| Purpose                              | Entity ID                               | Notes                                           |
|--------------------------------------|-----------------------------------------|-------------------------------------------------|
| PV energy today (forecast)           | `sensor.energy_production_today`        | Estimated production for the current day        |
| PV energy tomorrow (forecast)        | `sensor.energy_production_tomorrow`     | Estimated production for tomorrow               |
| Time of today’s production peak      | `sensor.power_highest_peak_time_today`  | Timestamp of expected production peak today     |
| Time of tomorrow’s production peak   | `sensor.power_highest_peak_time_tomorrow` | Timestamp of expected production peak tomorrow |
| Forecast power now                   | `sensor.power_production_now`           | Instantaneous forecasted PV power               |
| Forecast power next 24h              | `sensor.power_production_next_24hours`  | Total power forecast for the next 24h           |
| Forecast energy current hour         | `sensor.energy_current_hour`            | Forecast energy for the ongoing hour            |
| Forecast energy next hour            | `sensor.energy_next_hour`               | Forecast energy for the next hour               |
| Remaining energy today               | `sensor.energy_production_today_remaining` | Remaining forecast production for today     |

**Planned use:**  
These sensors will feed future **battery charging**, **EV charging**, and **export planning** logic once the core energy and peak-shaving modules are in place (Tasks 14+ / 30+).

### Wind–Price Correlation

Legacy 1.1/1.2 logic (`weather_energy.yaml`) used external wind forecasts to correlate with Nordpool prices.  
In 1.3 this logic is **not active** and will be **rebuilt later** as part of a dedicated energy market correlation module.

---

## 🧪 3. Template Sensors & Utility Meters

### 🧠 HA1 Template Sensor Framework (Task 14)

**Purpose:**  
Normalize all vendor-specific power sensors into clean, watt-based HA1 templates used by dashboards, flows, and automation logic.

#### Raw W-normalized sensors (`sensor.ha1_raw_*`)

| Sensor | Meaning | Source Sensor |
|--------|---------|---------------|
| `sensor.ha1_raw_grid_import_w` | Grid import (W) | `sensor.qp57qz4q_import_power` |
| `sensor.ha1_raw_grid_export_w` | Grid export (W) | `sensor.qp57qz4q_export_power` |
| `sensor.ha1_raw_ev_charger_w` | EV charger AC power (W) | `sensor.ehxdyl83_power` |
| `sensor.ha1_raw_battery_power_w` | Battery net power (W, +charge / −discharge) | `sensor.battery_charge_discharge_power` |
| `sensor.ha1_raw_solar_pv_input_w` | Solar PV input (W) | `sensor.inverter_input_power` |
| `sensor.ha1_raw_inverter_power_w` | Inverter AC output (W) | `sensor.inverter_active_power` |
| `sensor.ha1_raw_huawei_meter_w` | Huawei CT meter (W, diagnostic only) | `sensor.power_meter_active_power` |

All `ha1_raw_*` templates handle kW→W conversion, noise filtering, and sign normalization to provide clean, comparable values in watts.

#### Canonical power layer (`sensor.ha1_power_*`)

| Sensor | Meaning |
|--------|---------|
| `sensor.ha1_power_grid_total_net` | Net grid power (W), +import / −export (from normalized Easee import/export). |
| `sensor.ha1_power_solar_ac` | Solar AC contribution (W), based on inverter PV input. |
| `sensor.ha1_power_battery_net` | Battery net power (W), +charging / −discharging (from Huawei LUNA battery). |
| `sensor.ha1_power_ev_charger` | EV charging power (W), from Easee charger. |
| `sensor.ha1_power_house_total` | Total house consumption including EV (W). |
| `sensor.ha1_power_house_core` | House core consumption excluding EV (W). |

#### Flow layer (`sensor.ha1_flow_*`)

| Sensor | Meaning |
|--------|---------|
| `sensor.ha1_flow_grid_import` | Grid → house/EV import flow (W), derived from net grid power. |
| `sensor.ha1_flow_grid_export` | House/battery → grid export flow (W), derived from net grid power. |
| `sensor.ha1_flow_ev_charging_power` | EV charging flow (W). |
| `sensor.ha1_flow_battery_discharge` | Battery → house discharge flow (W). |

#### Sanity checks

| Sensor / Binary Sensor | Meaning |
|------------------------|---------|
| `sensor.ha1_power_balance_error` / `_abs` | Model balance error between grid, solar, battery and house load (W). |
| `sensor.ha1_grid_meter_mismatch` / `_abs` | Difference between Huawei CT meter and HA1 grid model (W, debug only). |
| `binary_sensor.ha1_flag_power_balance_bad` | True if |model balance error| > 500 W. |
| `binary_sensor.ha1_flag_grid_meter_mismatch` | True if |Huawei–model mismatch| > 4000 W. |

#### Extended power metrics (Task 15)

| Sensor | Meaning |
|--------|---------|
| `sensor.ha1_power_consumption_total_kw` | Total house consumption incl. EV load in kW (wrapper over `sensor.ha1_power_house_total`). |
| `sensor.ha1_power_consumption_core_kw` | Core house consumption without the EV charger, exposed in kW. |
| `sensor.ha1_power_net_load_kw` / `_abs_kw` | Signed and absolute net grid load (kW) for dashboards/guards. |
| `sensor.home_load` | Back-compat alias that now mirrors the HA1 house-load math (W). |

#### Rolling averages / smoothing sensors

| Sensor | Source | Window | Purpose |
|--------|--------|--------|---------|
| `sensor.ha1_power_grid_net_avg_1m` | `sensor.ha1_power_grid_total_net` | 1 min | Stabilize fast automations reacting to net grid power swings. |
| `sensor.ha1_power_grid_net_avg_5m` | `sensor.ha1_power_grid_total_net` | 5 min | Planning/peak tracking that needs slower trends. |
| `sensor.ha1_flow_grid_import_avg_1m` / `_5m` | `sensor.ha1_flow_grid_import` | 1 / 5 min | Smooth import-only flows for dashboards and fuse guards. |
| `sensor.ha1_flow_grid_export_avg_1m` / `_5m` | `sensor.ha1_flow_grid_export` | 1 / 5 min | Smooth export-only flows for export caps + diagnostics. |

## HA1 Extended Template Metrics (Task 15)

These sensors form the “second layer” of HomeAssistant 1.3’s energy-logic model.  
They provide planning-friendly abstractions, grid/battery limits, smoothed values, and stability signals used by peak control, export handling, EV logic, and dashboards.

All `ha1_power_*` sensors use **W** unless the name explicitly ends with `_kw`.

---

### 🔷 Meta Sensors (Derived kW, %)  

| Entity ID | Description | Unit | Based On |
|----------|-------------|------|----------|
| **sensor.ha1_ev_share_of_house_load_pct** | EV charging as a percentage of total household load. Useful for detecting when EV dominates consumption. | % | `ha1_power_ev_charger`, `ha1_power_house_total` |
| **sensor.ha1_effective_peak_power_reference_kw** | Effective peak limit currently enforced by the system. Placeholder until Task 16 introduces helper-driven rule (incl. 22–06 0.5 factor). | kW | `input_number.ha1_peak_limit_kw` (future) |
| **sensor.ha1_peak_margin_kw** | Difference between current total consumption (kW) and the effective peak limit. Negative = under limit, positive = over limit. | kW | `ha1_power_consumption_total_kw`, `ha1_effective_peak_power_reference_kw` |

---

### 🔷 Battery Charging Capability Metrics (Huawei Limits)

These expose the real physical constraints of your Huawei inverter/LUNA system.

| Entity ID | Description | Unit | Based Based On |
|----------|-------------|------|----------------|
| **sensor.ha1_batt_grid_charge_limit_kw** | Maximum battery **grid-charging power** the inverter will accept. Clamped to **2.5 kW** as per hardware limit. | kW | `number.battery_grid_charge_maximum_power` (W) |
| **sensor.ha1_batt_total_charge_limit_kw** | Maximum **overall** battery charge rate (grid + solar). Reflects the inverter’s full charging capability. | kW | `number.battery_maximum_charging_power` (W) |

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

This framework defines the "brain" power signals used by automations and visual flows in HA 1.3.

This section will list:

- Template sensors for flows (solar → battery, battery → house, house → grid, etc.).
- Utility meters for:
  - Daily/weekly/monthly energy.
  - Monthly peak demand.
- Rolling averages and peak-shaving helpers.

*(To be filled in once we reintroduce the packages.)*

---

## 🧰 4. Helpers (Inputs)

This includes:

- `input_boolean`, `input_number`, `input_select`, etc.
- Roles:
  - Enable/disable optimization modes.
  - Set thresholds (max peak, min SOC, price levels).
  - Comfort overrides.
  - Debug/diagnostic flags.

*(To be filled in when helpers are created.)*
