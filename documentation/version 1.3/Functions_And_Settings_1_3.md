Last updated: 2025-11-15 16:47 (CET) — Authorized by ChatGPT

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

**Controlled by (planned):**
- Peak target slider(s).
- Booleans for:
  - “Peak shaving enabled”
  - “Allow comfort override”
- Related sensors from grid meter and utility meters.

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

---

## Task 11 functions/settings (Placeholder)

Details for Task 11 will be documented here once the feature is defined and scoped to the HomeAssistant 1.3 baseline.

---

## 5. Comfort Overrides

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

## 6. Export / Import Strategy

**Goal:**  
Define rules for when export is allowed and when energy should be used locally or stored in the battery.

**Considerations:**
- Never export solar while battery needs charging (unless manually overridden).
- Use hysteresis or averaging to avoid rapid toggling of export states.
- Respect contractual limitations if any.

---

## 7. Logging, Diagnostics & Safety

**Goal:**  
Provide enough data to understand why the system behaved a certain way.

**Planned elements:**
- Key sensors grouped in diagnostic views.
- Logbook-friendly messages for major actions (start/stop charging, change mode, hit new peak, etc.).
- Simple debug toggles (extra logging on/off).

---

Further sections will be filled in as functions are implemented and tuned in 1.3.

## 8. Climate / AC

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
