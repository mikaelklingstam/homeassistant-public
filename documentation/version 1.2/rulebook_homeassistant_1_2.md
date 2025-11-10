# 🧭 HomeAssistant 1.2 – Rulebook

## 📘 General Info (Priority 1)
Installation
- Installation method: Home Assistant OS
- Core 2025.11.1 / Supervisor 2025.11.1 / OS 16.3 / Frontend 20251105.0
- Config directory: \\192.168.2.130\config

All dashboards and UI text must be written in English.

## 🧭 Mission (Priority 1)
Create an intelligent, self-learning, and fully integrated home system where energy optimization, safety, and comfort work together automatically. The system continuously adapts to electricity prices, peak charges, availability, weather, and presence to minimize cost, maximize efficiency, and improve quality of life — without manual control. With clearly defined boundaries, it functions like a self-playing piano that learns from historical data and earlier version experiences.

## ⚙️ Integrations / Sensors Overview (Priority 1)
Includes Huawei Solar & Battery, Easee EV Charger, Nordpool pricing, Utility Meter, Easee, Verisure, presence tracking, media players, and environment sensors.

## ⚖️ Contradictions / Resolutions (Priority 2)
1. Battery optimization vs. peak shaving → peak shaving has priority.
2. Peak power counted as 50% between 22:00–06:00.
3. Separate manual and AI thresholds.
4. Solar energy never exported if battery needs charging.
5. Nordpool price is definitive; forecast used only for long-term planning.
6. Centralized Easee charger control script.
7. Power used for instantaneous logic; energy for meters/history.
8. Hourly synchronization of price, weather, and power data.
9. Expandable mission boundaries (max peak, min SOC, export hours, comfort exceptions).

## 🔋 Functions & Logic Guidelines (Priority 2)
### Peak Shaving
Handles monthly power peaks (Ellevio). Thresholds can be manual or AI-learned. AI suggestions stay within safe boundaries. Power 22–06 counts as 50%.

### Electricity Price / Forecast
Uses Nordpool as main data source. Forecast and weather influence long-term logic. Recognizes recurring low-price patterns (weekends, sunny/windy hours).

## 🎨 Visual & Control (Priority 1)
Purpose: Defines unified visual and control philosophy for the entire system.

### Core Principles
1. Unified Interface – All dashboards integrated. One control may affect multiple subsystems.
2. Flow Visualization – Live map: Solar → Battery → House / EV / Grid. Animated color-coded arrows (Green=Export, Blue=Import, Orange=Partial, Red=Error). Power values (kW) beside arrows, refresh ≤2s.
3. Modern + Clear Design – Clean layout using custom:button-card or Mushroom.
4. Control Hierarchy – Primary (UI), Secondary (Settings/AI), Tertiary (Backend).
5. Settings Transparency – Show cause/effect; simple sliders/inputs.
6. Responsive Layout – Adaptive grid preserving flow topology.

### Implementation Hints
Main layout: /config/dashboards/energy_flow_1_2.yaml
Use custom:button-card over the picture-elements grid so the HA1 flow arrows keep their gradients and rotations.
Data flows through the `ha1_*` aliases defined in `packages/energy_core.yaml`, such as `sensor.ha1_solar_power`, `sensor.ha1_house_power`, `sensor.ha1_grid_power`, `sensor.ha1_flow_battery_to_grid_ac`, and the Battery/EV helper sensors. This avoids tying the UI to raw integration IDs.

## ⚗️ Potential Conflicts – Under Observation (Priority 4)
1. Shared optimization budget coordinating subsystems.
2. Comfort override may break peak limits but must show visual indication.
3. AI suggestions expire after each 15-minute interval.
4. Export stability via 1–2 min averaging or ±200W hysteresis.
5. Short-term automations use live data; long-term planners use snapshots.
6. AI training uses normalized peak data (pre 0.5 factor).
7. All dashboard thresholds must also appear in Settings as linked controls.
