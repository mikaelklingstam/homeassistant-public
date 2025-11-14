Last updated: 2025-11-13 22:15 (CET) — Authorized by ChatGPT

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

---

## 4. EV Charging (Easee + ID.4)

**Goal:**  
Charge the EV at the right time and power level considering:
- Departure time.
- `sensor.id4pro_charging_time_left`
- Price and peak constraints.

**Key concepts (planned):**
- Latest allowed finish time (departure).
- Required energy or charging time.
- Price-aware start time calculation.
- Peak-aware throttling of charging current.

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
