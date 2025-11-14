Last updated: 2025-11-13 22:15 (CET) — Authorized by ChatGPT

# 🔌 Integrations & Sensors – HomeAssistant 1.3

**Purpose:**  
Document all integrations and their important entities (sensors, switches, numbers, etc.) used in HomeAssistant 1.3, with focus on energy optimization, safety, and comfort.

This file is the **technical reference**; the rulebook remains the high-level description.

---

## 📦 1. Core Energy Integrations

### 1.1 Huawei Solar & LUNA2000 (Huawei Solar integration)

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

**Diagnostic / secondary (Huawei Solar meter)**

- `sensor.power_meter_active_power` (W)
- `sensor.power_meter_phase_a_active_power` / `_b_` / `_c_` (W)
- `sensor.power_meter_consumption` (kWh import)
- `sensor.power_meter_exported` (kWh export)

These are used for detailed PV/battery flow views and cross-checking the P1 grid meter, but **all peak shaving, Nordpool/ha1 planners, EV and export logic** must reference the *canonical* grid sensors above.

---

### 1.3 Easee EV Charger

- **Role:** EV charging control and load balancing.
- **Key sensors/entities (to be filled in):**
  - `sensor.ehxdyl83_power`
  - `sensor.id4pro_battery_level` (if available)
  - `sensor.id4pro_charging_time_left`
  - Charger mode, current limit, and status entities.

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

### 1.5 Verisure

- **Role:** Alarm, door/window sensors, maybe smart plugs.
- **Key sensors/entities (to be filled in).**

---

## 🌡️ 2. Environment & Weather

### 2.1 Local Weather

- **Role:** Temperature, humidity, and general conditions for comfort logic.

### 2.2 Wind & Price Correlation (if reused)

- **Role:** Wind forecast and its correlation with price trends (based on 1.1/1.2 logic).

---

## 🧪 3. Template Sensors & Utility Meters

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
