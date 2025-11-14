Last updated: 2025-11-13 22:15 (CET) — Authorized by ChatGPT

# 🔌 Integrations & Sensors – HomeAssistant 1.3

**Purpose:**  
Document all integrations and their important entities (sensors, switches, numbers, etc.) used in HomeAssistant 1.3, with focus on energy optimization, safety, and comfort.

This file is the **technical reference**; the rulebook remains the high-level description.

---

## 📦 1. Core Energy Integrations

### 1.1 Huawei Solar & Battery

- **Inverter:** SUN2000 (model details TBD)
- **Battery:** LUNA2000 modules
- **Key roles:**
  - Measure solar production.
  - Control/monitor battery charge and discharge.
  - Support peak shaving and export limitations.

**Key sensors/entities (to be filled in):**
- `sensor.huawei_solar_input_power`
- `sensor.huawei_battery_charge_discharge_power`
- `sensor.huawei_battery_soc`
- …

---

### 1.2 Grid Meter / Import–Export

- **Role:** Track real-time import/export power and total energy.
- **Key sensors/entities (to be filled in):**
  - `sensor.grid_import_export_power`
  - `sensor.power_meter_active_power`
  - Utility meters for monthly peaks and energy.

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

- **Role:** Hourly electricity price and planning for cheap/expensive periods.
- **Key sensors/entities (to be filled in):**
  - Base Nordpool sensor for SE3.
  - Planner/cheapest-hours sensors.
  - High/low price threshold helpers.

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
